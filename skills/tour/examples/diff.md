# Example: diff tour

The tour of a branch's changes, cut down to show the patterns. Only the flows the diff touches. It shows: a box for a call inside a callback, placed after the callback closes (Flow A); a method that is a list of cases, shown as `case → result` lines (`renameRefusalOf`, Flow A); a one-line method that still gets a box because it calls code with logic (`loadDomain`, Flow B); a method shown once and then referred to (`→ see B4`); a ✏️ step with 🟢 / 🔴 marks (Flow D).

````markdown
# 🧭 Tour: Your branch `feat/support-renames-slug`
Repo: offplan · 83 files · base `dev` · commit `022c4619` · 2026-11-18

## 1. What it is

**The change.** An Admin can now change a Project's Slug: `harbour.dev.offplan.tools` becomes
`harbour-bay.dev.offplan.tools`. The old address sends visitors on (301) for 12 months, then says "gone" (410) for 12 more.

**Problem it solves.** A typo at signup ("harbur") stayed forever. And a changed Slug would break
every printed link. → issue #355, ADR-0033

**What it doesn't do.**
- No job yet moves an old address from 301 to 410 when its date passes.

📖 **Words**
- **Slug**: the short name in a Project's address, `harbour`. → CONTEXT.md
- **Held**: a retired address that still answers (301, then 410). Only its own Project may take it back. → CONTEXT.md
- **Row lock** (`FOR UPDATE`): a second transaction that wants the same row waits until the first one commits.

---
# ⚙️ BACK-END

## 2. 📦 Data

**Table `domain`**: one row is one address of a Project. Project "Harbour Bay" renamed from `harbour` to `harbour-bay`:

| when | host | status | source | redirect_until | change_reason |
|---|---|---|---|---|---|
| 🔴 before | harbour.dev.offplan.tools | active | signup | – | – |
| 🟡 saved | harbour-bay.dev.offplan.tools | **pending_route** | **rename** | – | **"Rebranded"** |
| 🟢 route on | harbour.dev.offplan.tools | **redirect** | signup | **2027-11-18** | **"Rebranded"** |
| 🟢 route on | harbour-bay.dev.offplan.tools | **active** | rename | – | "Rebranded" |

- 🆕 One `active` subdomain per Project (index `domain_live_host_unique`). So the old host turns `redirect` before the new one turns `active`, in one transaction.
- One row per host while not `released` (index `domain_host_unique`). A held host blocks every other Project.

## 3. 🗺️ Parts map

```
 operator console ──► DomainController ──► DomainRenameService ──┬─► SlugClaimService ─► SlugClaimRepository
                                                                  ├─► ProjectRepository (lock, change slug)
                                                                  └─► DomainService ─► HostRouter ─► Cloudflare
 Stripe "paid" ─► SubscriptionService ─► DomainService.attachHostOf
```

- **`DomainRenameService`** 🆕 · `domain/domain-rename.service.ts` — checks a new Slug, and changes it · ⚠️ calls Cloudflare after the commit; a Cloudflare failure does not fail the rename
- **`SlugClaimService`** 🆕 · `slug/slug-claim.service.ts` — answers "who claims this Slug?" for both a Checkout and a rename
- **`DomainService`** ✏️ · `domain/domain.service.ts` — `activate` is now the one place where a host goes live
- **`renameRefusalOf`** 🆕 · `domain/util/rename-refusal-of.ts` — a claim → why a rename may not take the Slug, or `null`

🧩 **New idea: "go live" retires the old host in the same transaction**
A Project has one `active` subdomain. So "new host active" and "old host redirect" must happen together.
`DomainService.activate` does both in one transaction. Until it commits, the old host still serves.
→ ADR-0033, amendment 2026-11-18

## 4. 🔀 Flows

### Flow A: `GET /operator/domains/:id/slug-availability`: check a new Slug while it is typed

```
A0. 🆕 DomainController.slugAvailabilityOf           🛡️ domain.rename (Admins)
  └ A1. 🆕 DomainRenameService.availabilityOf
       ├ 🆕 findProjectOf (private)                  → 404 domain-not-found
       └ 🆕 SlugClaimService.availabilityOf
            ├ slugSchema check                       → { availability: invalid }
            ├ 🆕 SlugClaimService.claimOf
            └ callback → renameRefusalOf
```

**Story.** Ann types `harbour-bay`. After a short pause the console asks this route.
Nobody claims `harbour-bay`, so Ann sees a green "Available" badge.

#### 🆕 A0. `DomainController.slugAvailabilityOf()`
`domain/domain.controller.ts:78` · 🚪 `GET /operator/domains/:id/slug-availability` from front-end Flow G · ➡️ A1
🧱 **DomainController**: the operator routes for Domains.
📝 Checks the id and the permission, then passes the id and the typed Slug on. No logic.
🏁 200 from A1 · 400 id is not a UUID · 403 not an Admin · 404 from A1

```ts
@RequirePermission('domain.rename')                               // Admins only; the global guard checks it
@Get('domains/:id/slug-availability')
async slugAvailabilityOf(
  @Param('id', ParseUUIDPipe) id: string,                         // the id must be a UUID, else 400 before our code
  @Query({ schema: slugAvailabilityRequestSchema }) { slug }: …,
): Promise<SlugAvailabilityResponse> {
  return this.renames.availabilityOf(id, slug);                   // the Domain id and the typed Slug → A1
}
```

#### 🆕 A1. `DomainRenameService.availabilityOf()`: who claims the Slug, as a rename sees it
`domain/domain-rename.service.ts:57` · ⬅️ A0
📝 Loads the Domain's Project, asks who claims the Slug, and turns the claim into a rename answer.
🏁 200 free · invalid (bad format) · taken + reason · 404 domain-not-found
💡 **Why a callback?** A Checkout and a rename share one claim rule, but each turns a claim into its own answer. → `slug/slug-claim.service.ts`

```ts
async availabilityOf(id: string, slug: string): Promise<SlugAvailabilityResponse> {
  const project = await this.findProjectOf(id);                                      // Project first: unknown Domain → 404, even for a bad Slug

  ┌─ 🆕 findProjectOf(id) (private) · domain-rename.service.ts:89
  │ 📝 Domain id → its Project's id, name and current Slug.
  │ 🏁 the Project · 404 domain-not-found
  │
  │ const domain = await this.domains.findRenamable(id);                             // the Domain + its Project id, fresh from the DB
  │ const project = domain?.projectId && (await this.projects.findSlugOf(…));        // the Project's id, name and current Slug
  │ if (!project) throw new DomainNotFoundException();                               // no Domain, or no Project behind it → 404 domain-not-found
  │ return project;
  └─

  return this.slugClaims.availabilityOf(slug, (claim) => {                           // shared check; the callback turns a claim into a reason
    const refusal = renameRefusalOf(project, slug, claim);
    return refusal === RenameRefusal.Unchanged ? RenameRefusal.Project : refusal;    // the wire has no "unchanged": sent as "project"
  });

  ┌─ 🆕 SlugClaimService.availabilityOf(slug, takenReasonOf) · slug/slug-claim.service.ts:33
  │ 📝 Checks the format, finds the claim, asks the callback if the claim means "taken".
  │ 🏁 invalid (reads no table) · taken + reason · free
  │
  │ if (!slugSchema.safeParse(slug).success) return INVALID_SLUG;                    // malformed (`Harbour Bay!`) → invalid, reads no table
  │ const takenReason = await takenReasonOf(await this.claimOf(slug));               // finds the claim, then asks A1's callback for a reason ↩ A1
  │
  │   ┌─ 🆕 SlugClaimService.claimOf(slug) · slug/slug-claim.service.ts:51
  │   │ 📝 Who claims the Slug now. Fixed order, the first match wins.
  │   │ 🏁 reserved · held (with ids) · project · checkout (with org id) · free
  │   │
  │   │ if (isReservedSlug(slug)) return { kind: Reserved };                         // our own name (`www`)? → reserved
  │   │ const domain = await this.claims.findDomainAt(hostOf(slug));                 // a Domain at this host, not released?
  │   │ if (domain) return isDomainHeld(domain.status) ? HELD : PROJECT;             // held → held (with ids); else → project
  │   │ if (await this.claims.hasProjectWithSlug(slug)) return PROJECT;              // a Project with this Slug? → project
  │   │ const holderId = await this.claims.findHolderOf(slug);                       // an open Checkout holds it? → checkout
  │   │ return holderId ? { kind: Checkout, organisationId: holderId } : FREE;       // else → free
  │   └─
  │
  │ return takenReason ? { availability: Taken, takenReason } : FREE_SLUG;           // a reason → taken; null → free
  └─

  ┌─ 🆕 renameRefusalOf(project, slug, claim) · domain/util/rename-refusal-of.ts:19
  │ 📝 Pure function: why this Project may not take this Slug, or null.
  │ its own Slug now → Unchanged
  │ its own old held address → null (it may take it back)
  │ any other claim → REFUSAL[claim.kind] (a fixed table; a new claim kind fails the build)
  └─
}
```

### Flow B: `POST /operator/domains/:id/rename`: change the Slug

```
B0. 🆕 DomainController.renameDomain                   🛡️ domain.rename (Admins)
  └ B1. 🆕 DomainRenameService.rename
       ├ B2. 🆕 recordRename (private)                  🔒 transaction  → 409 slug-taken / slug-held …
       ├ B4. 🆕 DomainService.attachHost                (after the commit; only for a new host)  🌍 Cloudflare
       └ 🆕 DomainService.loadDomain
```

**Story.** Ann types `harbour-bay`, a reason, and `harbour` to confirm. One transaction saves the new row and the
new Slug. After the commit, Cloudflare adds the route, and `harbour` turns `redirect`.

🗄️ **DB change**: the `domain` rows in **2. 📦 Data**, plus `project.slug` → **`harbour-bay`**, plus one `event` row `domain.rename`.

#### 🆕 B1. `DomainRenameService.rename()`: save, then attach the route
`domain/domain-rename.service.ts:74` · ⬅️ B0 · ➡️ B2, B4
📝 Saves the rename in one transaction, then asks Cloudflare for the new route.
🏁 200 the renamed Domain as JSON · 404 domain-not-found · 409 slug-taken / slug-held … (from B2)
💡 **Why Cloudflare after the commit?** So no database connection waits on an outside call. → BACKEND_STANDARDS.md

```ts
async rename(id, request, actor): Promise<Domain> {
  const renamed = await this.recordRename(id, request, actor);      // one transaction; returns { id, host, needsRoute } → B2
  if (renamed.needsRoute) {                                         // false when the Project took back its own old address
    await this.domainService.attachHost(renamed.id, renamed.host);  // asks Cloudflare for the route, after the commit → B4
                                                                    // a refusal is kept in lastError; the rename still counts
  }
  return this.domainService.loadDomain(renamed.id);                 // reads the new row again and turns it into the API shape

  ┌─ 🆕 DomainService.loadDomain(id) · domain/domain.service.ts:177
  │ 📝 Reads one Domain and turns it into the API shape.
  │ 🏁 the Domain · 404 domain-not-found
  │
  │ return toDomain(await this.findEntryOf(id));                    // the row with its Organisation, Project and changedBy name
  │
  │   ┌─ findEntryOf(id) (private) · domain/domain.service.ts:181
  │   │ 📝 One query for the row with everything the API shape needs.
  │   │ 🏁 the row · 404 domain-not-found
  │   │
  │   │ const entry = await this.domains.findEntry(id);             // one query: the row with its Organisation, Project, changedBy
  │   │ if (!entry) throw new DomainNotFoundException();            // no Domain, or no Project behind it → 404 domain-not-found
  │   │ return entry;
  │   └─
  └─
}
```

(B0, B2, B3, B4 left out of this example. B4 shows the box for `DomainService.attachHost` and `activate`.)

### Flow D: Stripe "paid" handled: attach the new Project's host

```
⏰ Provider event handled (Stripe "paid")
  └ SubscriptionService (after the commit)
       └ D1. ✏️ DomainService.attachHostOf               throws → event retried (ADR-0030)
            ├ 🆕 DomainRepository.findWaitingHostOf
            └ 🆕 attachHost → tryAttach 🌍 → applyOutcome → activate 🔒
```

**Story.** Bob pays for `marina`. After the commit the api attaches the route. New: `activate` also retires
the Project's live host, which a new Project doesn't have, so nothing else changes for Bob.

#### ✏️ D1. `DomainService.attachHostOf()`
`domain/domain.service.ts:142` · 🚪 `SubscriptionService`, after the commit · ➡️ B4
📝 Finds the Project's waiting host and attaches its route. ✏️ now finds the newest waiting row, not "the" one subdomain.
🏁 nothing (host live, or no waiting row) · throws the refusal → the event runs again (ADR-0030)

```ts
async attachHostOf(projectId: string): Promise<void> {
  const waiting = await this.domains.findWaitingHostOf(projectId);  // 🟢 the newest row still pending_route or failed
                                                                    // 🔴 was: findSlugDomainOf(projectId), "the" one subdomain
  if (!waiting) return;                                             // no waiting row → already live, or an old Project; stop
  const outcome = await this.attachHost(waiting.id, waiting.host);  // 🟢 adds the route; on success makes it live → see B4
  if (outcome?.refused) throw outcome.error;                        // a refusal → the event stays unhandled and runs again
}
```

## ❔ You could ask next
- What will the daily job do when `redirect_until` passes, and how will it delete the Cloudflare route?
- How does `HostRouter` in `cloudflare` mode decide "already attached"?
````
