---
name: solid
description: SOLID design for TypeScript, React and Node code. Use when writing a new module, service, class, component or feature; when refactoring code that mixes concerns; or when the user asks for clean, testable or SOLID code.
---

# SOLID design

Apply Uncle Bob's SOLID as a **design pass** before and while writing code. The user learned SOLID from Clean Coders; speak in those terms (actor, policy, detail, plugin, backwards coupling).

Scale the pass to the change. A one-line fix or a small edit inside one existing module gets only step 6. A new module, feature, or refactor gets every step. For a whole domain with many kinds (e.g. pay types, plans, channels), read [payroll.md](payroll.md): all five rules in one design.

## Steps

1. **Actors.** Name every group of people who would ask to change this code (e.g. Policy = business rules, Architecture = DB/storage, Operations = reports/UI). Done when each piece of planned code has exactly one actor.
2. **Split by actor (S).** One module per actor. Code that looks the same but serves two actors stays in two places. In React: rules in a plain `.ts` file, data in a hook, the component renders only. Examples: [srp.md](srp.md).
3. **Variants → plugins (O).** For each real `A | B | C` kind that exists today, make an interface plus one class/object per kind. The core calls the interface with no `switch` on kind; only factories / `main.ts` list all kinds. Use a Null Object instead of `if (!x)` branches. Build for variants the user needs now; add the interface when a second variant really appears. Examples (expense report, notifiers, React props): [ocp.md](ocp.md).
4. **Policy owns the interface (D).** Business rules import only interfaces that live beside them. DB, HTTP, Stripe, files, `fetch` implement those interfaces with `import type`. Wire everything in `main.ts` / the composition root (or React context for the API client). Use this at the edges (slow, external, swappable), plain imports everywhere else. Examples (repo, Stripe port, React context): [dip.md](dip.md).
5. **Narrow dependencies (I).** Each function, class and component takes only what it uses: `name: string` instead of `user: User`, `email` instead of `req`, `Pick<Ctx, "stripe" | "logger">` instead of the full context. Small interfaces per client; one big class may implement many. Examples: [isp.md](isp.md).
6. **Keep promises (L).** Every implementation honours the full behaviour callers expect from its type: every method works, same errors, same side effects. A subtype that can only partly promise gets a smaller shared interface. Prefer `readonly T[]` for array params of a base type. Test fakes behave like the real thing. Examples: [lsp.md](lsp.md).

## Finish

Done when every step above was applied (or skipped by the scaling rule). End the reply with a short **SOLID notes** block, simple English, one line per decision that mattered: which actors you found, which split / interface you made and why, and any place you chose the simpler design on purpose.
