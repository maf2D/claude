---
name: tour
description: "[mine] Write a tour of a module, a feature, one endpoint or page, or the branch's changes: what it is for, its parts, and every flow step by step with real code. Saved to docs/tours/."
disable-model-invocation: true
argument-hint: "a module or feature folder, an endpoint (POST /tags), a page; empty = the branch's changes"
---

Write a **tour**: a Markdown file that teaches the user how a piece of code works, so they can read code an AI wrote for them. The user is not a native English speaker: plain words, short sentences, one idea per sentence.

The tour is read-only for the code. You read code, run read-only commands, and write one file under `docs/tours/`.

## 1. Pick the target

| Argument | Target | File |
|---|---|---|
| a backend module or frontend feature folder | **module**: every flow it has | `docs/tours/<module>.md` |
| an endpoint (`POST /tags`), a page, a cron job | **flow**: that one flow | `docs/tours/<module>-<flow>.md` |
| empty | **diff**: only the flows the branch touches | `docs/tours/branch-<branch>.md` |

- **diff**: the base is `git merge-base dev HEAD` (no `dev` → `main`). The change is `git diff <base>` plus `git ls-files --others --exclude-standard`.
- A module with sub-folders that each hold their own service (`subscription/{checkout,plan,trial}`) → one file per sub-folder, plus `docs/tours/<module>.md` as a short index: what the module is, and a link per sub-folder.

Done when you know the target, the files it covers, and every flow's entry point: each controller method, each page or component that starts a request, and each start that is not an HTTP request (another module calling in, a cron job, app boot, a listener).

## 2. Trace the code

Follow every flow from its entry to the last call: controller → service → other services, private methods, repos; or route → component → hook → request function → API call. A frontend flow stops at the API call. A target spanning 5+ files → send `Explore` sub-agents (one per few flows) to return the call tree, `file:line` and the full code of every method we own; read the key files yourself after.

While tracing, collect:
- **Hidden behavior**: global guards, decorators that change data or block a request, transactions, callbacks, events, timers, code that runs at boot, error classes that become HTTP answers by themselves.
- **Outside calls**: external APIs, email, queues, Postgres `NOTIFY`.
- **Example data**: real table and column names from the entities, real enum values.
- **Reasons**: `CONTEXT.md` for project words, `docs/adr/` and code comments for every "why".

Done when every flow is traced to its end; every call into our own code is opened and read down to its leaves, one-line wrappers included (a one-line method that calls a method with logic is opened too); and every "why" you plan to write has a source (an ADR, a comment, a doc, the code). A reason with no source stays out.

## 3. Write the tour

Read [`FORMAT.md`](FORMAT.md), then the example for your case:
- a backend module → [`examples/backend-module.md`](examples/backend-module.md)
- a flow with many services or levels → [`examples/long-flow.md`](examples/long-flow.md)
- frontend → [`examples/frontend.md`](examples/frontend.md)
- back-end and front-end together → `examples/backend-module.md` and `examples/frontend.md`, laid out as the two halves in `FORMAT.md`
- **diff** → [`examples/diff.md`](examples/diff.md)

Write the file to `docs/tours/` at the repo root (`git rev-parse --show-toplevel`), wherever the session runs from; outside a git repo, at the current folder. An existing tour at that path is rewritten in full. Add `docs/tours/` to `$(git rev-parse --git-common-dir)/info/exclude` when it is missing there, so tours stay out of commits.

Then line up the comments with the script (it moves every `// ` comment in each code block to one column and changes nothing else):

```bash
python3 ~/.claude/skills/tour/scripts/align-comments.py docs/tours/<file>.md
```

Run it again after every later edit to a code block.

## 4. Check the file

Read the written file top to bottom once, as the reader, and fix what fails:
- Every flow from step 1 has its tree and its steps.
- Every call into our own code, in every code block, has a box, a `→ see <step>` comment, or a comment saying what its one-statement body does.
- Every box sits inside a code block, right after the statement that makes the call.
- Every step and every box opens with its card: 📝 and 🏁 always; 🏁 lists every return and every error.
- In each code block, every comment starts at the same column, right of the longest code line, on the line it describes; each says what its line does (a bare `→ see A1` or `→ 404` is too short). Explanations live in comments, the card, 🧩 or 🧠; the space under code holds no numbered list.
- Each method's code appears once in the whole file.

Done when every check holds on every step.

## 5. Tell the user

In chat: the file path, the flows it covers (one line each), and the 2–3 ideas that are hardest to see in the code.
