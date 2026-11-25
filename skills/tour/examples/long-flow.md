# Example: one long flow

A **flow** tour of one endpoint that goes through 3 levels: a private method, another module's service with a callback, a transaction with several repo calls, then an email. It shows nested boxes, a box too big that becomes its own step (A2), and one-query repo calls told in a comment.

````markdown
# 🧭 Tour: Sign-up: `POST /organisations/sign-up`
Repo: offplan · `apps/api/src/modules/organisation/organisation` · commit `bb40c6f` · 2026-11-13

## 1. What it is

**What it does.** A new customer creates their Organisation and their own owner account
from the public sign-up form. They get an email with a link to set their password.

**Problem it solves.** The owner's email must be proven before anyone signs in, and a half-made
sign-up (login made, Organisation not saved) must never block the email for a retry.

📖 **Words**
- **Organisation**: a customer company on the platform.
- **Slug**: the short name in the URL (`acme`). Unique.
- **WorkOS**: the outside service that holds logins and passwords.
- **Set-up link**: an emailed link where a new person sets their password. Works 7 days.
- **Event**: one record of "who did what, and when". Written once, never changed.

## 2. 🔀 Flow

### Flow A: `POST /organisations/sign-up`: a new customer signs up

```
POST /organisations/sign-up → A0. OrganisationPublicSignUpController.signUp   🌐 public  🚦 rate limit
  └ A1. OrganisationService.signUpOrganisation
      └ createWithNewOwner (private)
          ├ OrganisationRepository.isSlugTaken                 → 409 slug taken
          ├ A2. IdentityCreationService.create                 → 409 email taken
          │     ├ WorkOS createUser                            🌍 makes the login
          │     └ createWithNewOwnerAndRecord (private)        🔒 transaction
          │           ├ OrganisationRepository.insert           → 409 slug taken
          │           ├ OrganisationRepository.insertPendingOwner → 409 email taken
          │           ├ SetUpLinkService.issue + insertSetUpToken
          │           └ EventService.record
          └ InviteService.send                                 ✉️ set-up link email
```

**Story.** Bob signs up as "Acme" with slug `acme`. We make his WorkOS login, then save the
Organisation, Bob as a pending owner, a set-up token and an Event in one transaction. If the DB
part fails, the WorkOS login is deleted again. Last, Bob gets an email with a link.

🗄️ **DB change** (Bob signs up as Acme)

`organisation`: 1 new row
| id | name | slug | signup_source | chosen_plan_key |
|---|---|---|---|---|
| `0194…a1` | Acme | acme | signup | pro |

`organisation_user`: 1 new row
| id | organisation_id | email | status | workos_user_id |
|---|---|---|---|---|
| `0194…b2` | `0194…a1` | bob@acme.com | pending | `user_01J…` |

`set_up_token`: 1 new row (only the hash). `event`: 1 new row, `organisation.create`, by Bob.

#### A0. `OrganisationPublicSignUpController.signUp()`
`organisation-public-sign-up.controller.ts:29` · 🚪 `POST /organisations/sign-up` · ➡️ A1
🧱 **OrganisationPublicSignUpController**: the one public route for sign-up, with its own rate limit.
📝 Checks the form, then passes it and the browser name on. No logic.
🏁 201 from A1 · 400 bad form · 429 too many sign-ups · 409 from A1
💡 **Why its own controller?** In a class marked `@SessionAuth()`, a method's `@Public()` would silently win. A separate class makes it plain. → ADR-0022

```ts
@UseGuards(RateLimitGuard)                                                      // limits sign-ups per client; each claims a slug + email (ADR-0018)
@Public()                                                                       // the global guard lets it through with no login
@Controller('organisations')
export class OrganisationPublicSignUpController {
  @Post('sign-up')
  async signUp(@Body({ schema: signUpOrganisationRequestSchema }) body, ...) {
    return this.organisations.signUpOrganisation(body, userAgent);              // passes the form and the browser name on → A1
  }
}
```

#### A1. `OrganisationService.signUpOrganisation()`: check, create, email
`organisation.service.ts:192` · ⬅️ A0 · ➡️ A2
🧱 **OrganisationService**: the Organisation rules, for sign-up and for staff-made Organisations.
📝 Creates the Organisation with Bob as its owner, then emails Bob his set-up link.
🏁 201 the new Organisation as JSON · 409 slug-taken · 409 email-taken (from A2)
💡 **Why the email after the transaction?** If the email fails, Bob's row is already saved, so staff can resend the link. → comment in `invite.service.ts`

```ts
async signUpOrganisation({ planKey, ...request }: SignUpOrganisationRequest, userAgent) {
  return this.createWithNewOwner(request, {                                                // shared with staff-created Organisations
    signupSource: SignupSource.Signup,
    chosenPlanKey: planKey ?? null,
    actorOf: (ownerId) => ({ organisationUserId: ownerId, userAgent }),                    // a function: Bob's id doesn't exist yet
  });

  ┌─ createWithNewOwner(request, source) (private) · organisation.service.ts:204
  │ 📝 Checks the slug, makes the login and our rows (A2), then sends the email.
  │ 🏁 the new Organisation · 409 slug-taken · 409 email-taken
  │
  │ if (await this.organisations.isSlugTaken(request.slug)) {                              // one query on organisation.slug; before WorkOS
  │   throw new SlugTakenException();                                                      // the slug is used already → 409 slug-taken
  │ }
  │ const { token, created } = await this.identities.create(request.owner,
  │   (workosUserId) => this.createWithNewOwnerAndRecord(request, source, workosUserId));  // WorkOS, then our rows ↩ → A2
  │ await this.invites.send(created.owner, token);                                         // sends Bob the email with his set-up link
  │
  │   ┌─ InviteService.send(organisationUser, token) · invite/invite.service.ts:27
  │   │ 🧱 InviteService: sends the emails that carry a set-up link.
  │   │ 📝 Builds the set-up link email and sends it.
  │   │ 🏁 nothing · throws when the mailer fails
  │   │
  │   │ const content = await setUpLinkEmail({ name, link: this.linkFor(token) });         // the console's /invite?token=… page
  │   │ await this.mailer.send({ to: organisationUser.email, ...content });                // sends it; Mailer is AWS SES in prod and a fake in tests
  │   └─
  │
  │ return created;
  └─
}
```

#### A2. `IdentityCreationService.create()`: WorkOS login, then our DB, with undo
`iam/authentication/identity-creation.service.ts:24` (from the `iam` module) · ⬅️ A1
🧱 **IdentityCreationService**: makes a person's WorkOS login and their row in our DB, for every kind of user.
📝 Checks the email is free, makes the WorkOS login, runs the caller's insert, and deletes the login again if the insert fails.
🏁 the caller's rows, back to A1 · 409 email-taken · any error from `insert` (after the undo)
💡 **Why WorkOS outside the transaction?** An HTTP call inside a transaction holds a DB connection while it waits. → comment in `identity-creation.service.ts`, BACKEND_STANDARDS.md

```ts
async create<Row>(identity: NewIdentity, insert: (workosUserId: string) => Promise<Row>) {
  if (await this.operators.isEmailTaken(email) ||
      await this.organisationUsers.isEmailTaken(email)) {
    throw new EmailTakenException();                                                              // one email = one person (ADR-0027) → 409
  }
  const workosUserId = await this.identities.createUser({ ...identity, email });                  // Bob's WorkOS login, no password yet
  try {
    return await insert(workosUserId);                                                            // runs A1's arrow function, which saves our rows ↩ A1

    ┌─ createWithNewOwnerAndRecord(request, source, workosUserId) (private) · organisation.service.ts:351
    │ 📝 Saves the Organisation, Bob as pending owner, a set-up token and an Event. All or nothing.
    │ 🏁 { token, created } · 409 slug-taken · 409 email-taken
    │
    │ @Transactional()                                                                            // the 4 writes below save together, or none of them does
    │ const organisation = await this.organisations.insert({ name, slug, ... });
    │ if (!organisation) throw new SlugTakenException();                                          // slug taken since A1's check → 409
    │ const owner = await this.organisations.insertPendingOwner(organisation.id, request.owner);
    │ if (!owner) throw new EmailTakenException();                                                // the email got used in between → 409 email-taken
    │ const { token, ...setUpToken } = this.setUpLinks.issue();                                   // random token; only its hash is saved
    │ await this.organisationUsers.insertSetUpToken(owner.id, setUpToken);
    │ await this.events.record({ actor: source.actorOf(owner.id), ... });                         // the audit Event; Bob's id exists now, so actorOf can run
    │ return { token, created };
    └─

  } catch (error) {
    await this.deleteQuietly(workosUserId);                                                       // DB failed → free the email at WorkOS
    throw error;
  }
}
```

🧩 **New idea: a callback**
`create` doesn't know how to save an Organisation. So the caller gives it a function
(`insert`), and `create` runs it at the right moment: after WorkOS, inside its `try`.
"Undo WorkOS if the DB fails" is written once for every kind of user.

## ❔ You could ask next
- What happens when Bob opens the set-up link?
- How does `RateLimitGuard` count requests?
````
