# Example: backend slices

Two slices from one feature (support renames a Project's slug). Slice 1 shows nested boxes. Slice 4 shows a big method moved to its own section (R1).

````markdown
### Slice 1: GET /operator/domains/:id/slug-availability — is the new slug free?

```
GET /operator/domains/:id/slug-availability → DomainController.slugAvailabilityOf   🛡️ domain.rename
  └ 🆕 DomainRenameService.availabilityOf
      ├ 🆕 findProjectOf (private)                            → 404 domain-not-found
      │     ├ 🆕 DomainRepository.findRenamable
      │     └ ✏️ ProjectRepository.findSlugOf
      └ 🆕 SlugClaimService.availabilityOf                    (moved out of SlugService)
            ├ 🆕 SlugClaimService.claimOf
            │     ├ isReservedSlug (util, reused)
            │     └ 🆕 SlugClaimRepository: findDomainAt, hasProjectWithSlug, findHolderOf
            └ 🆕 renameRefusalOf (util, given as callback)
```

**Story.** Ann renames "harbour-view" and types "harbour". The form asks this endpoint.
"harbour" belongs to another Project → `{ availability: "taken", takenReason: "project" }`.

**DB change:** none (read only).

```ts
// DomainController · domain/domain.controller.ts
// 📝 Reads id (UUID) and slug (query), passes on. No logic.
// 🏁 200 answer · 400 bad UUID · 403 no domain.rename · 404 from service

@RequirePermission('domain.rename')
@Get('domains/:id/slug-availability')
async slugAvailabilityOf(@Param('id', ParseUUIDPipe) id, @Query(slugAvailabilityRequestSchema) { slug }) {
  return this.renames.availabilityOf(id, slug);

  ┌─ 🆕 DomainRenameService.availabilityOf(id, slug) · domain/domain-rename.service.ts
  │ 🧱 New service: all rename logic (check here, rename in Slice 4). DomainService is already big.
  │ 📝 Loads the Project of the Domain, asks "who claims this slug", turns the claim into a rename answer.
  │ 🏁 free · invalid (bad format) · taken + reason · 404 unknown Domain or no Project
  │
  │ const project = await this.findProjectOf(id);                    // first: unknown id is 404 even for a bad slug
  │
  │   ┌─ 🆕 findProjectOf(id) (private)
  │   │ 📝 Domain id → id and current slug of its Project.
  │   │ 🏁 ProjectSlug · 404 domain-not-found
  │   │
  │   │ const domain = await this.domains.findRenamable(id);         // 🆕 repo, one query: org, projectId, kind, status
  │   │ const project = domain?.projectId
  │   │   && await this.projects.findSlugOf(domain.projectId);       // ✏️ repo, one query: Project id + slug
  │   │ if (!project) throw new DomainNotFoundException();           // no Domain, or Domain without Project → 404
  │   └─
  │
  │ return this.slugClaims.availabilityOf(slug, (claim) => {         // callback: rename decides what "taken" means
  │   const refusal = renameRefusalOf(project, slug, claim);
  │
  │     ┌─ 🆕 renameRefusalOf(project, slug, claim) · domain/util/rename-refusal-of.ts
  │     │ 📝 Pure function: why this Project cannot use this slug, or null.
  │     │ 🏁 Unchanged · null (free or its own held old slug) · Reserved / Project / Held / Checkout
  │     │
  │     │ if (slug === project.slug) return Unchanged;               // same as now
  │     │ if (claim.kind === Held && claim.projectId === project.id)
  │     │   return null;                                             // its own old slug: may take it back
  │     │ return REFUSAL[claim.kind];                                // a Record: a new kind breaks the build until mapped
  │     └─
  │
  │   return refusal === Unchanged ? Project : refusal;              // own current slug shows as "taken by a Project"
  │ });
  │
  │   ┌─ 🆕 SlugClaimService.availabilityOf(slug, takenReasonOf) · slug/slug-claim.service.ts
  │   │ 🧱 New service: "who claims this slug now?". Moved out of SlugService so Checkout
  │   │    and rename read one rule. SlugService keeps its method and calls this inside.
  │   │ 📝 Checks format, finds the claim, asks the callback if the claim means "taken".
  │   │ 🏁 invalid (no DB read) · taken + reason · free
  │   │ 💡 Callback: Checkout and rename treat claims differently (own hold / own old slug is free).
  │   │
  │   │ if (!slugSchema.safeParse(slug).success)
  │   │   return { availability: Invalid, takenReason: null };       // bad format: stop before any query
  │   │ const takenReason = await takenReasonOf(await this.claimOf(slug));
  │   │ return takenReason ? { availability: Taken, takenReason } : FREE_SLUG;
  │   │
  │   │   ┌─ 🆕 SlugClaimService.claimOf(slug)
  │   │   │ 📝 Who claims the slug. Fixed order, first match wins.
  │   │   │ 🏁 Reserved · Held (domainId, projectId) · Project · Checkout (organisationId) · Free
  │   │   │
  │   │   │ if (isReservedSlug(slug)) return { kind: Reserved };     // our own names (www, api…), no query
  │   │   │ const domain = await this.claims.findDomainAt(hostOf(slug));
  │   │   │                                                          // 🆕 repo: Domain at that host, not released
  │   │   │ if (domain) return isDomainHeld(domain.status)
  │   │   │   ? { kind: Held, domainId, projectId }                  // old address, still redirecting
  │   │   │   : { kind: Project };                                   // a live address
  │   │   │ if (await this.claims.hasProjectWithSlug(slug))          // 🆕 repo: count Projects with this slug
  │   │   │   return { kind: Project };
  │   │   │ const holderId = await this.claims.findHolderOf(slug);   // 🆕 repo: org of an open Checkout's hold
  │   │   │ return holderId ? { kind: Checkout, organisationId: holderId } : { kind: Free };
  │   │   └─
  │   └─
  └─
}
```

**New / changed**
- 🆕 types: SlugClaim, SlugClaimKind, RenameRefusal, RenamableDomain, ClaimingDomain
- 🆕 SlugClaimRepository: 3 read-only methods above, one query each
- ✏️ api-contract: SlugTakenReason gets `held`

**Tests**
- e2e: free · reserved · other Project's · own current slug · own held old slug → free · bad format → invalid · unknown id → 404 · no permission → 403
- unit renameRefusalOf: one per claim kind + "held by itself → null"
- existing Checkout slug tests stay green (the move changed nothing)
````

## Slice 4, the own-section part

`rename` calls `recordRename`, which is over 15 lines with its own boxes, so its call line points to a section after the main code block:

````markdown
```ts
  │ const renamed = await this.recordRename(id, request, actor);       // 🔒 all DB writes → R1
```

#### R1. 🆕 DomainRenameService.recordRename(id, request, actor) (private)
📝 Checks every rule, then writes the new slug, its Domain and an Event. All or nothing.
🏁 RenamedHost { id, host, needsRoute } · 404 · 409 domain-not-live · 400 rename-not-confirmed · 409 slug-unchanged / slug-reserved / slug-held / project-slug-taken
💡 @Transactional + row lock: two renames of the same Project run one after the other.

```ts
@Transactional()
private async recordRename(id, { slug, reason, confirmSlug }, actor): Promise<RenamedHost> {
  const project = await this.projects.lockSlugOf(domain.projectId);  // 🆕 repo: Project id+slug, SELECT … FOR UPDATE
  …
  this.throwIfRefused(renameRefusalOf(project, slug, claim));        // renameRefusalOf → see Slice 1

    ┌─ 🆕 throwIfRefused(refusal) (private)
    │ 📝 Turns a refusal into its HTTP error. null → nothing.
    │ Unchanged → 409 slug-unchanged · Reserved → 409 slug-reserved · Held → 409 slug-held
    │ Project, Checkout → 409 project-slug-taken
    └─
  …
}
```
````

Its DB change, schema only:

```
- domain_source enum: + 'rename'                  → we can mark a Domain made by a rename
- new unique index domain_live_host_unique         → one 'active' subdomain per Project
- no new columns (retired_at, redirect_until, changed_by already exist)
```
