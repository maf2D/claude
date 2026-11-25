# Walkthrough format

## Parts

Each shape uses the parts marked for it, in this order.

| Part | line | feature | diff | finding |
|---|---|---|---|---|
| `## 🧭 <title>` + `File:` | ✓ | ✓ | ✓ | ✓ |
| Diagram | | ✓ (3+ parts talk) | ✓ (3+ parts talk) | |
| **Story** | | ✓ | ✓ | |
| **What it does** / **What is wrong** | ✓ | | | ✓ |
| Code | ✓ | in steps | in items | ✓ |
| 📖 **Words** | ✓ | ✓ | ✓ | ✓ |
| Numbered items | | steps `### 1.` | ideas `### 1.` | |
| 🔴 **Before** / 🟢 **After** | | | ✓ | ✓ |
| 💡 **Why** | ✓ | ✓ | ✓ | ✓ |
| **Example** input table | when a value changes the result | | | |
| 🛠️ **Possible solutions** + ⚖️ **My view** | when asked | when asked | when asked | ✓ |
| ❔ **You could ask next** | ✓ | ✓ | ✓ | ✓ |

- **Diagram**: plain text boxes and arrows in a code block, max ~12 lines.
- **Story**: 5–8 short lines. What happens, told as one real case ("A user pays on Stripe. Stripe sends us…").
- **Items**: 3–6. **feature** → one per step of the flow, in order. **diff** → one per idea of the change, like `/polish` items, each with a `Why:` of 2–4 sentences.
- **Code**: the real code, up to ~15 lines. Bigger → an outline: signatures, bodies cut to `// ...` or `/* what it does */`, the key lines in full, `// ← here` on the line that matters.
- 🔴 **Before** / 🟢 **After**: inside a quote block (`>` on every line, a blank `>` line between them), with `· <file>` when it spans several files. A **finding** uses the same headers for the change not made yet.
- 📖 **Words**: every project word (from `CONTEXT.md`) and every code word a beginner may not know (guard, DTO, webhook), one line each, the first time it shows up.
- 💡 **Why**: one or two lines, ending `→ ADR-<n>` or `→ comment in <file>` when that is the source.
- **Example** table: `input | value | result`, max 4 rows.
- 🛠️ **Possible solutions**: one quote block with 🔴 **Before**, then 🟢 **After 1: <short name>**, 🟢 **After 2: …**, max 3. Under each After one line: `Cost: … Good: … Bad: …` (cost = files, call sites, tests it touches). Only one good solution → a single 🟢 **After**.
- ⚖️ **My view**: one line after the solutions, which one you pick and when; clearly yours.
- ❔ **You could ask next**: 2–3 questions that go one level deeper.

## line

````markdown
## 🧭 Why `signature` is checked to be a string
File: `provider-event.service.ts:46`

> ```ts
> const signature = headers[this.provider.signatureHeader];
> // Sent twice, a header arrives as an array; no provider signs that way.
> signature: typeof signature === 'string' ? signature : undefined,
> ```

**What it does.** It takes Stripe's signature from the request headers. If it is not a plain string, it passes `undefined` instead.

💡 **Why.** In Node, a header is usually a string. If the same header is sent two times, Node gives an array. Stripe never does that, so an array means someone else sent the request. `undefined` makes the check fail → 400. → comment in `provider-event.service.ts`

**Example**
| Header sent | `signature` | Result |
|---|---|---|
| `stripe-signature: t=1,v1=abc` | `'t=1,v1=abc'` | checked |
| sent two times | `['…','…']` → `undefined` | 400 |
| missing | `undefined` | 400 |

📖 **Words**
- **Signature**: a code Stripe adds to prove the message is from Stripe.

❔ **You could ask next**
- Where is the signature actually checked?
- Why do we need the *raw* body for this?
````

## feature

````markdown
## 🧭 Provider events: how Stripe tells us about payments
Files: `provider-webhook.controller.ts`, `provider-event.service.ts`, `handle-provider-events.ts`

```
Stripe ──POST /webhooks/stripe──▶ ProviderWebhookController
                                        │
                                        ▼
                               ProviderEventService.receive()
                                 │ 1. check signature
                                 │ 2. save event (once)
                                 │ 3. run handlers ──▶ SubscriptionService ──▶ DB
                                 ▼
                          answer 200 (always)
```

**Story.** A user pays on Stripe. Stripe sends us a message about it. We check the message is really from Stripe, save it, and update the subscription. If the update fails, we still tell Stripe "OK", because the message is saved. A person can run a script later to try again.

📖 **Words**
- **Provider event**: one message Stripe sends us (invoice paid, subscription changed). We keep each one once.
- **Handler**: code that acts on an event.
- **Webhook**: Stripe calls *our* URL when something happens.

### 1. Check it is really Stripe
File: `provider-event.service.ts`
Anyone can call our URL. So Stripe signs each message, and we check the signature. Wrong signature → 400, nothing saved.

> ```ts
> const signature = headers[this.provider.signatureHeader];
> const providerEvent = this.provider.readEvent({ rawBody, signature: ... });
> ```

### 2. Run handlers, never throw
If a handler fails, we only log it. The event stays "not handled".

> ```ts
> } catch (error) {
>   this.logger.error({ ... }, 'Provider event not handled; it stays unhandled');
>   return false;
> }
> ```

💡 **Why 200 even when it fails?** If we answer 500, Stripe sends it again and again. We already saved it, so we fix it on our side. → ADR-0020

❔ **You could ask next**
- What does `SubscriptionService` change in the DB for each event type?
- What happens if Stripe is down when the handler runs?
````

## diff

The `/polish` item format (`~/.claude/skills/polish/SUMMARY.md`, "One item") with a longer `Why:` and the shared parts around it:

````markdown
## 🧭 Your branch: price math moved into Plan
Files: `checkout.service.ts`, `plan.entity.ts`

**Story.** Before, the checkout code calculated the price itself. Now the Plan knows its own price, and checkout just asks for it.

📖 **Words**
- **Plan**: what an owner pays for (price, months).

### 1. Price math moved into Plan
Files: `checkout.service.ts`, `plan.entity.ts`
Why: `CheckoutService` read Plan's fields to calculate the price. A second place that needs a price would copy this code, and the two copies would drift apart. Now there is one place to change.

> 🔴 **Before** · `checkout.service.ts`
>
> ```ts
> const total = plan.basePrice * plan.months
> const discount = plan.months >= 12 ? total * 0.1 : 0
> ```
>
> 🟢 **After** · `plan.entity.ts`, `checkout.service.ts`
>
> ```ts
> class Plan {
>   totalPrice(): number { /* base × months, −10% from 12 months */ }
> }
>
> const amount = plan.totalPrice()          // ← moved to Plan
> ```

❔ **You could ask next**
- Is `totalPrice()` tested on its own now?
````

## finding

````markdown
## 🧭 Q3: `handleQuietly` returns `true`/`false`
File: `provider-event.service.ts:95`
Review says: return what happened, not a boolean.

**What is wrong.** `true` / `false` tells you *if* it worked, but not *why* it failed. The error is logged and then lost.

💡 **Why it may matter.** The planned retry timer saves `last_error` per event. With a boolean the error is gone. → ADR-0030

### 🛠️ Possible solutions

> 🔴 **Before**
>
> ```ts
> private async handleQuietly(event): Promise<boolean> {
>   try { /* run handlers, mark handled */ return true }
>   catch (error) { this.logger.error(...); return false }
> }
> ```
>
> 🟢 **After 1: result type**
>
> ```ts
> type HandleResult = { ok: true } | { ok: false; error: string }
>
> private async handleQuietly(event): Promise<HandleResult> { /* same, error kept */ }
> ```
>
> Cost: 1 type, 2 call sites. Good: the caller decides what to do with the error. Bad: more code today.
>
> 🟢 **After 2: save the error inside handleQuietly**
>
> ```ts
> catch (error) { await this.providerEvents.saveError(event.id, error); return false }
> ```
>
> Cost: 1 repository method. Good: callers stay the same. Bad: a DB write inside a `catch`.

⚖️ **My view:** After 1, together with ADR-0030. Today nobody reads the error.

❔ **You could ask next**
- Where would `last_error` be saved?
````
