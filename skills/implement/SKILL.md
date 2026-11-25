---
name: implement
description: "[mine] Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

First, make sure you are on a branch for this work, created from `dev` (or the default branch if there is no `dev`).

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at the seams the spec names; if it names none, /tdd confirms them with me.

Use /solid when designing new modules, services or components.

Run typechecking regularly, and single test files regularly.

Done when every acceptance criterion in the spec has code and a passing test, and typecheck is green.

Then run /polish, passing it the spec or tickets you worked from. It runs the full test suite.

Leave the work uncommitted, and say so at the end.
