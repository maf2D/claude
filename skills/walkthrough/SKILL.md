---
name: walkthrough
description: "[mine] Explain a piece of code, a feature, the branch's changes, a review finding or any tech question in simple words, with real code, before/after, why and possible fixes."
disable-model-invocation: true
argument-hint: "a feature, path, line, finding id (Q3), pasted finding or question; empty = the branch's changes"
---

Write a **walkthrough**: an explanation the user reads in chat to understand code. The user is not a native English speaker: short sentences, plain everyday words, one idea per sentence. A plain word beats a clever one every time.

The walkthrough is read-only. You read code, run read-only commands (`git diff`, `grep`) and write the answer in chat. Files stay as they are; if the user then says "ok, do it", that is a normal message after the skill.

## 1. Pick the shape

The argument decides the **shape**. The answer's size follows the code's size.

| Argument | Shape |
|---|---|
| one line, one function, one small block | **line** |
| a feature, a flow, a module, a folder | **feature** |
| empty | **diff**: the branch's changes |
| a finding id from this chat (`Q3`, `T1`, `A2`) or a pasted review finding | **finding**: a change not made yet |
| a question outside this repo (an editor, a tool, a config) | **line** or **feature**, by how much it covers |

A finding id with no matching finding in this chat → ask the user to paste it.

A **finding** always gets 🛠️ **Possible solutions**. Any other shape gets them when the request asks how to fix something.

Done when you know the shape and the code it covers.

## 2. Read the code

- **diff**: the base is `git merge-base dev HEAD` (no `dev` → merge-base with `main`). The change is `git diff <base>` plus `git ls-files --others --exclude-standard` (new files are untracked).
- **feature** spanning 5+ files → send an `Explore` sub-agent to trace the flow and return file paths, the call order and short code excerpts. Smaller → read it yourself.
- Every shape: look up project words in `CONTEXT.md`, and the reasons in `docs/adr/` and code comments, when the repo has them.
- A question outside the repo: read the real config (e.g. `~/.config/nvim`) and run read-only commands to see what really happens. Show their output as proof.

Done when you can follow the code from start to end, and every "why" you plan to write has a source: an ADR, a code comment, a ticket, or the code itself. A reason with no source stays out. A command output counts as a source.

## 3. Write it

Read [`FORMAT.md`](FORMAT.md) and write the walkthrough in its format for your shape.
