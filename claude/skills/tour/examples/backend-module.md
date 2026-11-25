# Example: backend module tour

A small NestJS module with 4 endpoints. It shows every part. Flows A and B show a repository method in a box inside its caller's step. Flow C is short because its steps are simple.

````markdown
# 🧭 Tour: Tag module
Repo: offplan · `apps/api/src/modules/tag` · commit `bb40c6f` · 2026-11-13

## 1. What it is

**What it does.** Staff (Operators) keep one shared list of tags, like "VIP" or "Late payer".
They put these tags on Organisations, so they can filter and group them.

**Problem it solves.** Without tags, staff have no simple way to mark a group of
Organisations. Free text would let "VIP" and "vip" become two different tags.

**What it doesn't do.** Putting a tag *on* an Organisation is in `OrganisationController`.

📖 **Words**
- **Operator**: a member of offplan staff. Works in the operator console.
- **Organisation**: a customer company on the platform.
- **Event**: one record of "who did what, and when". Written once, never changed.
- **Archive**: hide a tag, but keep it on the Organisations that already have it.
- **Decorator** (`@Something`): a label on a class, method or parameter. Nest reads it and does work for you (routing, checks, filling values).

## 2. 📦 Data

**`tag`**: the shared tag list
| id | name | status | archived_at |
|---|---|---|---|
| `0193…a1` | VIP | active | – |
| `0193…b2` | Late payer | archived | 2026-11-02 |

**`organisation_tag`**: which Organisation has which tag
| organisation_id | tag_id |
|---|---|
| `0191…c3` (Acme Ltd) | `0193…a1` (VIP) |
| `0191…d4` (Bolt Inc) | `0193…b2` (Late payer) |

- `name` is unique in any capitals: you can't add "vip" when "VIP" exists. → comment in `db/entities/tag.ts`
- An archived tag keeps its `organisation_tag` rows. Bolt still has "Late payer", but it's hidden.

## 3. 🗺️ Parts map

```
HTTP ─▶ TagController ─▶ TagService ─┬▶ TagRepository ─▶ DB (tag, organisation_tag)
                                     ├▶ EventService  ─▶ DB (event)
                                     └▶ toTag / toTagListItem (mappers)
```

- **`TagController`** · `tag.controller.ts` — the 4 endpoints under `/operator/tags` · ⚠️ archive and restore answer 204, not 201
- **`TagService`** · `tag.service.ts` — the rules: "name taken → 409", "an Event on every real change"
- **`TagRepository`** · `tag.repository.ts` — reads and writes `tag` · ⚠️ returns `undefined` for "not found" or "name taken", never throws
- **`EventService`** · `modules/event/event/event.service.ts` (from the `event` module) — writes one Event row; joins the caller's transaction
- **Mappers** · `util/to-tag.ts` — a DB row → the API shape (dates become ISO text)

🧩 **New idea: the global guard**
You won't see a guard on `TagController`, but every request here passes one.
`IamModule` adds `AuthenticationGuard` to the whole app (`APP_GUARD`). It checks the session cookie,
then `@RequirePermission(...)`. No session → 401. Missing permission → 403. → `modules/iam/iam.module.ts:120`

## 4. 🔀 Flows

### Flow A: `POST /operator/tags`: create a tag

```
POST /operator/tags → A1. TagController.createTag  🛡️ organisation.tag_manage
  └ A2. TagService.createTag                       🔒 transaction
      ├ TagRepository.create                       → 409 name taken
      ├ EventService.record                        (audit log)
      └ toTag                                      (row → API shape)
```

**Story.** Ann types "Premium" and clicks Add. If "premium" is already there, she gets 409.
Else the tag is saved, an Event "Ann created tag Premium" is written, and the tag goes back.

🗄️ **DB change**: `tag` gets 1 row (`Premium`, `active`); `event` gets 1 row `organisation.tag_create` by Ann.

#### A1. `TagController.createTag()`: check and pass on
`tag.controller.ts:43` · 🚪 `POST /operator/tags` · ➡️ A2
📝 Checks the body and the permission, then passes the body and "who did it" on. No logic.
🏁 201 from A2 · 400 bad body · 403 no organisation.tag_manage · 409 from A2

```ts
@RequirePermission('organisation.tag_manage')                        // only roles with this get in (the global guard)
@Post()
async createTag(
  @Body({ schema: createTagRequestSchema }) body: CreateTagRequest,  // zod check from api-contract; bad body → 400
  @ActiveOperator() operator: OperatorRow,                           // the Operator, fresh from the DB (ADR-0014)
  @Headers('user-agent') userAgent: string | undefined,
): Promise<Tag> {
  return this.tags.createTag(body, actorOf(operator, userAgent));    // the body + "who did it" for the Event → A2
}
```

#### A2. `TagService.createTag()`: save, record, return
`tag.service.ts:75` · ⬅️ A1
📝 Saves the tag and writes an Event in one transaction, then returns the tag.
🏁 201 the new Tag as JSON · 409 tag-name-taken
💡 **Why not "check first, then insert"?** Two clicks at once would both pass the check; the unique index lets only one win. → comment in `tag.repository.ts`

```ts
@Transactional()                                                                   // all saves together, or none (MikroORM)
async createTag(request: CreateTagRequest, actor: ActingOperator): Promise<Tag> {
  const tag = await this.tags.create({ name: request.name, ... });                 // the new tag, or undefined when the name is taken

  ┌─ TagRepository.create(input) · tag.repository.ts:83
  │ 📝 Inserts the tag, then reads the saved row back.
  │ 🏁 the saved Tag · undefined when the unique index refuses the name
  │
  │ try {
  │   const id = await this.entityManager.insert(Tag, { ... });                    // one SQL INSERT now, returns the id (MikroORM)
  │   return await this.entityManager.findOneOrFail(Tag, { id });                  // reads the saved row back, so we return the full tag
  │ } catch (error) {
  │   if (isUniqueViolation(error, TAG_NAME_UNIQUE)) return undefined;             // the unique index refused the name
  │   throw error;
  │ }
  └─

  if (!tag) throw new TagNameTakenException();                                     // no tag means the name is taken → 409 tag-name-taken
  await this.events.record({ actor, action: OrganisationTagCreate, ... });         // one insert, in the same transaction
  return toTag(tag);                                                               // turns the DB row into the API shape (dates as ISO text)
}
```

🧩 **New idea: errors become HTTP answers by themselves**
`TagNameTakenException` extends Nest's `ConflictException`, so Nest answers 409. Its `problemType`
lets `ProblemDetailsFilter` build a standard error body, so the front-end shows "name taken"
under the field. → `errors/problem-details.filter.ts`

### Flow B: `POST /operator/tags/:id/archive` and `/restore`

```
POST /:id/archive → B1. TagController.archiveTag    🛡️ organisation.tag_manage
POST /:id/restore → TagController.restoreTag        (same, other status)
  └ B2. TagService.setStatus                        🔒 transaction
      ├ TagRepository.setStatus                     → 404 no tag
      └ EventService.record                         only if something changed
```

**Story.** Ann archives "VIP". It leaves the picker, but Acme keeps it. A second archive does nothing.

🗄️ **DB change**: `tag` VIP: `status` active → **archived**, `archived_at` → **2026-11-13**; `event` gets 1 row `organisation.tag_archive`.

#### B1. `TagController.archiveTag()`
`tag.controller.ts:54` · 🚪 `POST /operator/tags/:id/archive` · ➡️ B2
📝 Checks the id, then asks B2 to set the status to archived.
🏁 204 empty body · 400 id is not a UUID · 404 from B2

```ts
@HttpCode(HttpStatus.NO_CONTENT)                                                    // answers 204 (empty body), not 201
@Post(':id/archive')
async archiveTag(@Param('id', ParseUUIDPipe) id: string, ...): Promise<void> {      // the id must be a UUID, else 400 before our code
  await this.tags.setStatus(id, TagStatus.Archived, actorOf(operator, userAgent));  // the id + new status → B2
}
```

#### B2. `TagService.setStatus()`: record only real changes
`tag.service.ts:50` · ⬅️ B1
📝 Sets the tag's status; writes an Event only when the status really changed.
🏁 nothing (204) · 404 tag-not-found

```ts
@Transactional()
async setStatus(id: string, status: TagStatus, actor: ActingOperator): Promise<void> {
  const tag = await this.tags.setStatus(id, status);                                    // sets the status; returns { name, isChanged }, or undefined

  ┌─ TagRepository.setStatus(id, status) · tag.repository.ts:55
  │ 📝 Loads the tag and writes the new status when it differs.
  │ 🏁 { name, isChanged } · undefined when there is no such tag
  │
  │ const tag = await this.entityManager.findOne(Tag, { id });                          // loads the tag by id; null when there is no such tag
  │ if (!tag) return undefined;
  │ const isChanged = tag.status !== status;                                            // is the new status different? false → no write, no Event
  │ if (isChanged) await this.entityManager.nativeUpdate(Tag, …);                       // one SQL UPDATE now (MikroORM)
  │ return { name: tag.name, isChanged };
  └─

  if (!tag) throw new TagNotFoundException();                                           // no tag with this id → 404 tag-not-found
  if (tag.isChanged) {                                                                  // already archived → no Event; safe to call twice
    await this.events.record({ action: …Archive or …Restore, ... });
  }
}
```

### Flow C: `GET /operator/tags`: list tags

```
GET /operator/tags → TagController.listTags     🛡️ organisation.view
  └ C1. TagService.listTags
      ├ TagRepository.findAll                   (active first, then by name)
      ├ TagRepository.countOrganisationsByTag   (raw SQL, skips deleted Organisations)
      └ toTagListItem                           (row + count → API shape)
```

**Story.** The Settings page shows every tag and how many Organisations use it.

#### C1. `TagService.listTags()`
`tag.service.ts:36` · 🚪 `GET /operator/tags` (the controller only passes on)
📝 Loads all tags and how many Organisations use each, at the same time.
🏁 200 the tag list as JSON

```ts
async listTags(): Promise<TagListResponse> {
  const [tags, counts] = await Promise.all([                                         // both queries at once (JS Promise.all)
    this.tags.findAll(),                                                             // one query: active first, then by name
    this.tags.countOrganisationsByTag(),                                             // one raw SQL: tag id → count
  ]);
  return { items: tags.map((tag) => toTagListItem(tag, counts.get(tag.id) ?? 0)) };  // a tag no Organisation uses is not in counts, so it gets 0
}
```

## ❔ You could ask next
- Where is a tag put on an Organisation, and what stops an archived tag being used?
- How does `EventService.record` join the transaction?
- What does the frontend do with the 409 "name taken"?
````
