---
name: implement-slices
description: "[mine] Implement a spec or tickets slice by slice: design each slice, the user approves it, a sub-agent builds it, the user reviews it."
disable-model-invocation: true
---

Build the work in the spec or tickets one **slice** at a time. The user approves every slice twice: its **design** before any code, and its code after. The user is not a native English speaker: plain words, short sentences.

You are the **coordinator**. You read code, write designs and talk with the user. A sub-agent builds each slice, so test runs and edits stay out of your context and it lasts the whole feature.

## Terms

- **Slice**: one piece the user can review alone.
  - **Foundation**: migration, entity fields, shared types, enums, error classes that later slices use. Slice 0, only when needed.
  - **Backend**: one route from top to bottom: controller method, service methods, repository methods, errors, tests.
  - **Frontend**: one user action on a page (open the rename box, see if a slug is free, send the form).
  - A slice keeps its size even when its design is long; a big method gets its own section in the design (see `DESIGN.md`).
- **Slice map**: the ordered list of slices, one line each: number, kind, title, and for frontend `needs: <backend slice numbers>`.
- **Stop**: you wait for the user's OK. Every design and every built slice ends on a stop.
- **Run ahead**: the user says "do the next 3 without stopping". Only then skip the stops for that many slices: design, build, next. At the end show all their reports together; the user reviews them as one diff, and you stage on the OK.

## 1. Branch

Make sure you are on a branch for this work, created from `dev` (or the default branch if there is no `dev`).

## 2. Slice map

Read the spec and the code it touches. Write the slice map in chat:

```
0. Foundation: migration (domain_source + 'rename'), RenameRefusal, new errors
1. Backend: GET /operator/domains/:id/slug-availability
2. Frontend: open / close the rename box               needs: –
3. Frontend: type a new slug → see if it is free       needs: 1
4. Backend: POST /operator/domains/:id/rename
5. Frontend: send rename, show result                  needs: 4
```

Order: foundation, then each backend route; a frontend slice comes right after the last backend slice it needs.

Stop. Done when the user approves the map. The map changes later only the same way: you propose the change, the user approves.

## 3. For each slice

### a. Design

Read [`DESIGN.md`](DESIGN.md) and the example for the slice kind, then read every file the slice touches, so each box says truly 🆕 new, ✏️ changed, or reused. Write the design in chat.

Stop. On a requested change, show again only the changed boxes, marked ✏️; the full design only if the user asks. Done when the user approves the design.

### b. Build

Start a new `general-purpose` sub-agent for the slice. Its prompt holds:

- the spec or tickets path;
- the approved design, word for word;
- the slices already done, one line each;
- these rules:
  - Use /tdd at the seams the design names: the design's tests first, red, then the code.
  - Use /solid for new modules, services and components.
  - Run typecheck and the slice's single test files.
  - The design is the contract. Small inner details (private helpers, local names) are yours. A change to a route, signature, behavior, error or test → stop and report it; change no code for it.
  - Leave git to the coordinator: edit files only.
  - Report: files changed, test and typecheck result (pass/fail with the failing output), and every place the code differs from the design.

When the sub-agent reports a design problem: show the user the problem and the fixed design boxes. Stop. After the OK, send the fixed design to the same sub-agent with `SendMessage`.

Done when the sub-agent reports the design's tests passing and typecheck green.

### c. Review

Tell the user, short: what was built, test and typecheck result, any difference from the design. Stop.

The user reviews the code with `git diff`: only this slice shows, because done slices are staged. Requested fixes go to the same sub-agent with `SendMessage`, then report again.

Done when the user approves.

### d. Stage

Run `git add -A`, then `git diff --stat`. Tell the user: "Slice <n> staged."

Done when `git diff --stat` prints nothing: the next slice's diff starts empty. Only then design the next slice.

## 4. Finish

Done with slices when every slice in the map is approved and every acceptance criterion in the spec has code and a passing test.

Then run /polish, passing it the spec or tickets you worked from. It runs the full test suite.

Leave the work uncommitted, and say so at the end.
