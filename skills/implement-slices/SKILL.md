---
name: implement-slices
description: "[mine] Implement a spec or tickets slice by slice: design each slice, the user approves it, a sub-agent builds it, the user reviews it."
disable-model-invocation: true
---

Build the work in the spec or tickets one **slice** at a time. The user approves every slice twice: its **design** before any code, and its code after. The user is not a native English speaker: plain words, short sentences.

You are the **coordinator**. You read code, write designs and talk with the user. A sub-agent builds each slice, so test runs and edits stay out of your context and it lasts the whole feature. What later slices must know lives in the **notes file**, not in your memory of earlier slices.

## Terms

- **Slice**: one piece the user can review alone.
  - **Foundation**: migration, entity fields, shared types, enums, error classes that later slices use. Slice 0, only when needed.
  - **Backend**: one route from top to bottom: controller method, service methods, repository methods, errors, tests.
  - **Frontend**: one user action on a page (open the rename box, see if a slug is free, send the form).
  - A slice keeps its size even when its design is long; a big method gets its own section in the design (see `DESIGN.md`).
- **Group**: 2–5 slices that together make one piece of logic, backend to frontend. Each group but the last ends with a group polish; the last group, and so a single group, gets only the final polish.
- **Owners**: 2–5 lines under the map saying which side decides each rule and which shared piece does each repeated job. Every design follows them.
- **Slice map**: the ordered list of slices, one line each: number, kind, title, and for frontend `needs: <backend slice numbers>`; slices sit under their group; the Owners lines follow.
- **Work folder**: `$TMPDIR/implement-slices-<branch, / as ->/`. Outside the repo, so nothing in it is committed. It holds:
  - `notes.md`, the **notes file**: the Owners lines, then one block per done slice: each new hook, component, helper, type and error as `name · file · one-line job`, and the words the slice uses for its actions.
  - `designs.md`: every approved design, word for word, latest version, in slice order. Polish reads it.
  - `changelog-<group>.md`: each group polish's change log.
- **Stop**: you wait for the user's OK. Every design, every built slice and every group polish ends on a stop.
- **Run ahead**: the user says "do the next 3 without stopping". Only then skip the stops for that many slices: design, build, next. At the end show all their reports together; the user reviews them as one diff, and you stage on the OK. A group polish still stops.

## 1. Branch

Make sure you are on a branch for this work, created from `dev` (or the default branch if there is no `dev`).

## 2. Slice map

Read the spec and the code it touches. Write the slice map in chat:

```
Group A: check a new slug
  0. Foundation: migration (domain_source + 'rename'), RenameRefusal, new errors
  1. Backend: GET /operator/domains/:id/slug-availability
  2. Frontend: open / close the rename box               needs: –
  3. Frontend: type a new slug → see if it is free       needs: 1
Group B: rename
  4. Backend: POST /operator/domains/:id/rename
  5. Frontend: send rename, show result                  needs: 4

Owners:
- api decides whether a slug is free and why not; the frontend only shows the answer.
- One hook writes a rename answer into the Domain cache; every rename mutation uses it.
```

Order: foundation, then each backend route; a frontend slice comes right after the last backend slice it needs. A group closes once its logic works end to end.

Owners: for each rule both sides could work out (a state, a date, an amount, "can the user do X"), name the side that decides it; for each job several slices repeat (a cache write, an error line, a lookup), name the one piece that does it.

Stop. Done when the user approves the map, groups and Owners. Then create the work folder and write the Owners lines into `notes.md`. The map changes later only the same way: you propose the change, the user approves, you update `notes.md`.

## 3. For each slice

At the first slice of a group, record the **group start**: `git write-tree` prints the tree id of everything staged so far.

### a. Design

Read [`DESIGN.md`](DESIGN.md), the example for the slice kind and `notes.md`, then read every file the slice touches, so each box says truly 🆕 new, ✏️ changed, or reused.

Before writing, match each new piece against `notes.md`: a piece that does a job a noted piece does is reused; a piece shaped like a noted sibling (a mutation hook, a confirm box, an error line) takes that sibling's shape; an action keeps the word the notes use. Write the design in chat; its Reuse part shows every match.

Stop. On a requested change, show again only the changed boxes, marked ✏️; the full design only if the user asks. Done when the user approves the design. Then write it into `designs.md`.

### b. Build

Start a new `general-purpose` sub-agent for the slice. Its prompt holds:

- the spec or tickets path;
- the approved design, word for word;
- the path of `notes.md`;
- the slices already done, one line each;
- these rules:
  - Read the repo standards before any code: `CODING_STANDARDS.md` and the one for the slice kind (`BACKEND_STANDARDS.md`, `FRONTEND_STANDARDS.md`), or whatever the repo names for writing code. Follow them in every edit.
  - Read `notes.md`: reuse the pieces it lists and use its words.
  - Use /tdd at the seams the design names: the design's tests first, red, then the code.
  - Use /solid for new modules, services and components.
  - The design's comments explain the design to the user and stay in the design. Code comments follow the repo standards.
  - Run typecheck and the slice's single test files.
  - The design is the contract. Small inner details (private helpers, local names) are yours. A change to a route, signature, behavior, error or test → stop and report it; change no code for it.
  - **Self-check** before you report: read your own `git diff` and fix what fails:
    - every comment gives a reason the code cannot show;
    - each repeated block, in this slice or against `notes.md`, is one helper;
    - each mode is its own method, not a boolean parameter; a `switch` on one type lives in one place;
    - each rule sits on the side the Owners lines name;
    - each name matches the words in `notes.md`.
  - Append this slice's block to `notes.md`.
  - Leave git to the coordinator: edit files only.
  - Report: files changed, test and typecheck result (pass/fail with the failing output), self-check fixes, and every place the code differs from the design.

When the sub-agent reports a design problem: show the user the problem and the fixed design boxes. Stop. After the OK, send the fixed design to the same sub-agent with `SendMessage`, and update `designs.md`.

Done when the sub-agent reports the design's tests passing, typecheck green and its `notes.md` block written.

### c. Review

Tell the user, short: what was built, test and typecheck result, self-check fixes, any difference from the design. Stop.

The user reviews the code with `git diff`: only this slice shows, because done slices are staged. Requested fixes go to the same sub-agent with `SendMessage`, then report again; a fix that renames or adds a shared piece updates `notes.md`.

Done when the user approves.

### d. Stage

Run `git add -A`, then `git diff --stat`. Tell the user: "Slice <n> staged."

Done when `git diff --stat` prints nothing: the next slice's diff starts empty. The last slice of a group that is not the last group → step 4. The last slice of the last group → step 5. Else design the next slice.

## 4. Group polish

Run /polish with these options:

- spec: the spec or tickets you work from;
- base: the group start tree;
- designs: the path of `designs.md`;
- rounds: 1 architecture, 1 review;
- full suite: skip;
- change log out: `changelog-<group>.md` in the work folder.

Show the user its summary. Stop. The user reviews the changes with `git diff`; requested fixes go to a new `general-purpose` sub-agent with the same build rules.

After the OK, bring `notes.md` up to date with the polish items: each rename, each new shared piece, each removed one. Then stage as in step 3d.

Done when `notes.md` matches the code and `git diff --stat` prints nothing. Then the next group.

## 5. Finish

Done with slices when every slice in the map is approved, every group but the last polished, and every acceptance criterion in the spec has code and a passing test.

Then run /polish with: the spec, `designs.md`, and every `changelog-<group>.md` as the starting change log. Other options keep their defaults: the full branch, full rounds, the full suite.

Leave the work uncommitted, and say so at the end.
