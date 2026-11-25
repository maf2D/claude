# Polish summary format

The summary `/polish` ends with. It reads like a slice design from `/implement-slices` (or a tour diff tour): the same call tree and nested boxes, now with each polish change shown in place as **before** and **after** code, split by dividers, with its reason above it. The user is not a native English speaker: simple words, short sentences.

## Sections, in this order

1. **📦 Feature**: name and ticket; `Why:` from the spec; `Before:` / `After:` as a concrete call, UI step or command output. No spec → say so and describe it from the code.
2. **⚠️ lines**: every `behaviour vs ticket` change and every ADR amended or `CONTEXT.md` term added, each naming its item id. First, because they are decisions the user didn't make.
3. **One section per touched slice**, in slice-map order, each opened by a `---` line. Slices polish didn't touch are left out. A slice whose design is missing → build its tree and boxes from the code, in the same style. **No slice designs at all** → one section per touched flow instead: `### Flow A: <entry>: <what it does>`, the entry being a route, a page, or what starts it (`app boot`, `called by ProjectService`), as in a tour diff tour.
4. **✏️ Small fixes**: renames, unused imports, typos; one bullet each with its file, no code.
5. **🚫 Not done**: `⚔️ Conflict:`, `⏭️ Skipped:` (with reason), `💡 Arch ideas not applied:` (the clean round's `Speculative` ones), `↩️ Undone:` (a red step that was restored). Omit an empty line.
6. `✅` (or `❌`) `Full suite: <colour>. Ticket: checked against #<n>` (or `skipped, no spec found`), then `Not committed. <n> files changed.`

## Item ids

`🏗️ A<n>` from the arch rounds, `🎫 T<n>` from the review's Spec axis, `🧹 Q<n>` from its Standards axis. Each kind counts from 1 across the whole summary. Tags:
- 🎫: `[missing]` (asked, not done → added), `[wrong]` (done incorrectly → fixed) or `[extra]` (not asked → removed), with a `Ticket:` quote (for `[extra]`, say the ticket doesn't ask for it).
- 🧹: `[rule: <file>]` with a `Rule:` quote, or `[smell: <name>]` with a `Smell:` line saying in a few words what the smell means.
- 🏗️: `⚠️ ADR-<n>` or `⚠️ differs from ticket` at the end when it applies.

## One section

1. **Title**: the slice's own title from its design (`### Slice <n>: <route or user action> — <what it does>`), or the flow title.
2. `Changes:` the ids in this section, then one bullet per item: `- <icon> **<id>. <what changed, short title>.** [tag]`, plus its `Ticket:` / `Rule:` / `Smell:` quote. The reason is not here; it sits in the code (💬).
3. **Tree**: the slice design's tree, with `← <id>` on the right of every line a change touches. A method polish added gets its own line. Flow mode: the call tree built from the code, same marks.
4. **Code**: the design's top code block with its nested boxes and cards, showing the code **as it is now**:
   - A box with a change keeps its card (📝 🏁, and 🧱 for a class polish added), then its code with each change written as a **change block** (below). A box header gets `← <id>` when its method changed.
   - A box with no change keeps only its header (ending `· no change`) and its 📝 line; its code is cut to `…`, unless the box holds a changed box.
   - Unchanged lines around a change stay as context, about 1–3 lines a side; the rest is `…`.
   - A section (`#### R1. …`) from the design that holds a change is shown the same way, after the main code block.
5. **New / changed** (only when polish changed types, errors, contracts or shared pieces) and **Tests** (tests polish added or changed), one line each, naming the item ids.

## Change block

Inside the code, at the place the change sits, at the indent of that code, with the box's `│ ` prefix:

```
│ 💬 A1 · Why: two queries and a null check answered one question.
│    Now the repository answers it, in one query.
│ ┄┄┄┄┄┄┄┄┄┄┄┄ 🔴 before ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
│ <the old lines, real code>
│ ┄┄┄┄┄┄┄┄┄┄┄┄ 🟢 after ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
│ <the new lines, real code>
│ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
```

- **💬** 1–2 lines: what was wrong, then what the change fixes. A change touching several places gives the reason at the first; later places say `💬 A1 · see above`.
- Card lines (📝 🏁 🧱 💡 💬) and divider lines are not code comments, so the terminal highlights them as code. Never write `'` or a backtick in them: one `'` opens a string and turns the rest of the block orange. Write "the row of the dashboard", not "the dashboard's row"; "cannot", not "can't"; name code without backticks (target, not `target`). Double quotes only in pairs on one line.
- Code only added → the 🔴 part is one line `(nothing: <what happened before>)`. Code only removed → the 🟢 part is `(nothing)`.
- Code moved to another method → a change block where it left, its 🟢 part a call line ending `→ <the new box>`; the new place is a box marked `← <id>`.
- Before and after are each up to ~15 lines; longer → an outline: signatures kept, bodies cut to `…` or `/* what it does */`, the lines that changed shown in full.
- Comments sit on the right of their lines, all in one column per code block, saying what the line does (tour style). Lines inside a change block need no 🟢 / 🔴 marks: the dividers carry that.

## Example

````markdown
## 📦 Feature: support renames a Project's slug (#355)
Why: a typo at signup stayed forever.
Before: `POST /operator/domains/:id/rename` → 404
After: `POST /operator/domains/:id/rename` → the renamed Domain; the old address sends visitors on (301).

⚠️ ADR-0033 amended: the Project lookup now lives in ProjectRepository (A1). Check.

---
### Slice 1: GET /operator/domains/:id/slug-availability — is the new slug free?
Changes: 🏗️ A1 · 🎫 T1 · 🧹 Q1

- 🏗️ **A1. `findProjectOf` uses one query.** ⚠️ ADR-0033
- 🎫 **T1. Your own current slug → `unchanged`.** [missing] Ticket: "typing the current slug says it is already the slug"
- 🧹 **Q1. Nested ternary split into two ifs.** [rule: BACKEND_STANDARDS] Rule: "no nested ternary"

```
GET …/slug-availability → DomainController.slugAvailabilityOf     🛡️ domain.rename
  └ 🆕 DomainRenameService.availabilityOf                          ← T1
      ├ 🆕 findProjectOf (private)                                 ← A1   → 404 domain-not-found
      │     └ 🆕 ProjectRepository.findSlugOfDomain                ← A1
      └ 🆕 SlugClaimService.availabilityOf
            ├ 🆕 SlugClaimService.claimOf                          ← Q1
            └ 🆕 renameRefusalOf (util, given as callback)
```

```ts
async slugAvailabilityOf(@Param('id', ParseUUIDPipe) id, @Query(…) { slug }) {
  return this.renames.availabilityOf(id, slug);

  ┌─ 🆕 DomainRenameService.availabilityOf(id, slug) · domain/domain-rename.service.ts  ← T1
  │ 📝 Loads the Project of the Domain, asks "who claims this slug", turns the claim into an answer.
  │ 🏁 free · invalid · taken + reason · 404 unknown Domain or no Project
  │
  │ const project = await this.findProjectOf(id);                    // first: unknown id is 404 even for a bad slug
  │
  │   ┌─ 🆕 findProjectOf(id) (private)  ← A1
  │   │ 📝 Domain id → id and current slug of its Project.
  │   │ 🏁 ProjectSlug · 404 domain-not-found
  │   │
  │   │ 💬 A1 · Why: two queries and a null check answered one question.
  │   │    Now the repository answers it, in one query.
  │   │ ┄┄┄┄┄┄┄┄┄┄┄┄ 🔴 before ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │   │ const domain = await this.domains.findRenamable(id);          // query 1: the Domain
  │   │ const project = domain?.projectId
  │   │   && await this.projects.findSlugOf(domain.projectId);        // query 2: its Project
  │   │ ┄┄┄┄┄┄┄┄┄┄┄┄ 🟢 after ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │   │ const project = await this.projects.findSlugOfDomain(id);     // one query: Domain join Project → id + slug
  │   │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │   │ if (!project) throw new DomainNotFoundException();            // no Domain, or no Project behind it → 404
  │   └─
  │
  │ 💬 T1 · Why: the ticket wants its own slug shown as "already the slug".
  │    The code showed "taken by a Project", which looked like someone else had it.
  │ ┄┄┄┄┄┄┄┄┄┄┄┄ 🔴 before ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │ return this.slugClaims.availabilityOf(slug, (claim) => {
  │   const refusal = renameRefusalOf(project, slug, claim);
  │   return refusal === Unchanged ? Project : refusal;              // own slug shown as "taken by a Project"
  │ });
  │ ┄┄┄┄┄┄┄┄┄┄┄┄ 🟢 after ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │ return this.slugClaims.availabilityOf(slug, (claim) =>
  │   renameRefusalOf(project, slug, claim));                        // the refusal goes out as it is: `unchanged`
  │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │
  │   ┌─ 🆕 SlugClaimService.availabilityOf(slug, takenReasonOf) · no change
  │   │ 📝 Checks format, finds the claim, asks the callback if the claim means "taken".
  │   │ …
  │   │ const takenReason = await takenReasonOf(await this.claimOf(slug));
  │   │
  │   │   ┌─ 🆕 SlugClaimService.claimOf(slug)  ← Q1
  │   │   │ 📝 Who claims the slug. Fixed order, first match wins.
  │   │   │ 🏁 Reserved · Held · Project · Checkout · Free
  │   │   │
  │   │   │ const domain = await this.claims.findDomainAt(hostOf(slug));
  │   │   │ 💬 Q1 · Why: a nested ternary hides two cases in one line.
  │   │   │    Two ifs show each case, and each gets its own comment.
  │   │   │ ┄┄┄┄┄┄┄┄┄┄┄┄ 🔴 before ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │   │   │ if (domain) return isDomainHeld(domain.status)
  │   │   │   ? { kind: Held, domainId, projectId }
  │   │   │   : { kind: Project };
  │   │   │ ┄┄┄┄┄┄┄┄┄┄┄┄ 🟢 after ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │   │   │ if (domain && isDomainHeld(domain.status))                // old address, still redirecting → Held
  │   │   │   return { kind: Held, domainId, projectId };
  │   │   │ if (domain) return { kind: Project };                     // a live address → Project
  │   │   │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  │   │   │ …
  │   │   └─
  │   └─
  │
  │   ┌─ 🆕 renameRefusalOf(project, slug, claim) · no change
  │   │ 📝 Pure function: why this Project cannot use this slug, or null.
  │   └─
  └─
}
```

**New / changed:** ✏️ api-contract: SlugTakenReason gets `unchanged` (T1) · 🆕 ProjectRepository.findSlugOfDomain (A1)
**Tests:** ✏️ e2e "own current slug" now expects `unchanged` (T1)

---
### Slice 4: POST /operator/domains/:id/rename — change the slug
Changes: 🎫 T2

- 🎫 **T2. Empty reason → 400.** [missing] Ticket: "the reason is required"

```
POST …/rename → DomainController.renameDomain                     🛡️ domain.rename
  └ 🆕 DomainRenameService.rename
      └ R1. 🆕 recordRename (private)  🔒                          ← T2   → 400 rename-reason-missing
```

#### R1. 🆕 DomainRenameService.recordRename() (private)  ← T2
🏁 RenamedHost · 404 · 400 rename-reason-missing · 409 slug-unchanged / slug-held / …

```ts
private async recordRename(id, { slug, reason, confirmSlug }, actor) {
  💬 T2 · Why: the ticket makes the reason required; an empty one was saved.
  ┄┄┄┄┄┄┄┄┄┄┄┄ 🔴 before ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  (nothing: an empty reason was saved)
  ┄┄┄┄┄┄┄┄┄┄┄┄ 🟢 after ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  if (!reason.trim()) throw new RenameReasonMissingException();      // empty reason → 400, before any lock
  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  const project = await this.projects.lockSlugOf(domain.projectId);  // SELECT … FOR UPDATE
  …
}
```

**New / changed:** 🆕 error RenameReasonMissingException → 400 rename-reason-missing (T2)
**Tests:** 🆕 e2e "empty reason → 400" (T2)

---
✏️ **Small fixes**
- renamed `data` → `providerEvent` (`subscription.listener.ts`)
- removed unused import `Logger` (`domain.controller.ts`)

## 🚫 Not done
- ⏭️ Skipped: Data Clumps in `rename()`, because the params are not always together.
- 💡 Arch ideas not applied: split SlugClaimRepository reads (Speculative).

✅ Full suite: green. Ticket: checked against #355.
Not committed. 14 files changed.
````
