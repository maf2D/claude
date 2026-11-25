---
name: polish
description: "Polish finished work on a branch, unattended: architecture rounds, then review-and-fix rounds, each until clean, ending in a summary that shows each change as before/after code inside its slice or flow. Use at the end of /implement, or when the user asks to polish, clean up or auto-review a branch."
---

Improve the branch's work without the user in the loop, then hand back one summary they can read before committing.

You are the **coordinator**. Sub-agents do every scan and every edit; you hold only their short reports, the change log and the gate results. Your context may already be large from implementing, so keep it that way: read reports, never the code itself.

The work stays **uncommitted**. No `git commit`, `git stash`, `git reset` or push at any point; the user reads the working tree and commits.

## Terms

- **Base**: the commit the branch left from. The change under polish is everything since it, committed or not.
- **Change log**: one line per change the loop has made, with its item id: `A<n>` from an arch round (marked `behaviour vs ticket` when it is), `T<n>` from the Spec axis, `Q<n>` from the Standards axis, as in `SUMMARY.md`. Every sub-agent gets it with this rule: _a change-log entry stays; if you think one is wrong, report it as a **conflict** instead of undoing it_. This is what stops arch and review rounds undoing each other.
- **Conflict**: a finding that would undo a change-log entry. Never fixed by the loop; the user decides.
- **Gate**: typecheck plus the tests for changed files. **Green** means every command exited 0.
- **Save point**: a snapshot of the whole working tree, untracked files included. `scripts/savepoint.sh save` prints a tree id; `scripts/savepoint.sh restore <id>` puts the tree back. (The script is in this skill's folder.)

## Options

A caller (such as `/implement-slices`) may pass any of these; each one missing takes its default.

- **spec**: the ticket or spec. Default: found in step 1.3.
- **base**: a commit or tree id; the change is everything since it. Default: found in step 1.1.
- **designs**: a file holding the approved slice designs. Default: the designs in this chat (step 1.5).
- **rounds**: the most architecture and review rounds. Default: 2 and 3.
- **full suite**: `skip` leaves out step 5. Default: run it.
- **starting change log**: files whose entries join the change log before round 1, each entry prefixed with its file name (`changelog-A: A1 …`). Default: none.
- **change log out**: a file the final change log is written to. Default: none.

## 1. Prepare

1. **Base**: the base option; else `git rev-parse --verify --quiet dev` → if it exists, `git merge-base dev HEAD`; else the merge-base with the default branch (`git symbolic-ref --short refs/remotes/origin/HEAD`, falling back to `main`).
2. **The change**: `git diff <base> --stat` plus `git ls-files --others --exclude-standard` (new files are untracked, so the diff alone misses them). Note which untracked files belong to the work; scratch notes and logs do not.
3. **Spec**: the spec option; else an issue number in `git log <base>..HEAD` messages or the branch name, fetched the way the repo's docs say (e.g. `docs/agents/issue-tracker.md`, else `gh issue view`). None found → the spec axis is skipped for the whole run; record that for the summary.
4. **Gate commands**: from `CLAUDE.md`, `README.md` and `package.json` scripts, including any project gotcha about what must be built before tests read it. Also find the **full suite** command.
5. **Slice designs**: the designs file; else the approved designs `/implement-slices` wrote in this chat, each slice's latest approved version, word for word. A design cut short by a summarized chat counts as missing for that slice. None (another caller, or `/polish` run alone) → the summary groups by flow.
6. Save point #0. Change log starts with the starting change log, else empty.

Done when you hold: base, file list, spec (or "none"), gate commands, full-suite command, slice designs (or "none"), save point #0.

## 2. Architecture rounds (up to 2, or the rounds option)

Find the architecture skill's text: `.claude/skills/improve-codebase-architecture/SKILL.md` in the repo if present, else `~/.claude/skills/improve-codebase-architecture/SKILL.md`. It is user-invoked, so the sub-agent reads it as a file.

**Scan sub-agent** brief:

- Read that file and follow its Explore step with the repo's `CONTEXT.md` and ADRs, with these overrides: scope is the change's current file list (re-run step 1.2's commands each round, since earlier rounds add files) plus the files they import directly; the change log and its conflict rule apply; walk the code yourself (no further sub-agents); write no HTML report and ask no questions.
- Return every candidate worth doing as text, one block each: files; problem; what changes; strength (`Strong` / `Worth exploring` / `Speculative`); kind (`structure` or `behaviour vs ticket`, the latter when the ticket's behaviour looks wrong and the candidate changes it, with the ticket line quoted); any ADR it contradicts; any new term it needs in `CONTEXT.md`.

Then a **fixer** (see Fixer brief) applies the candidates. A candidate may contradict an ADR or need a new term: apply it, add an amend note to the ADR, add the term to `CONTEXT.md`. Then run the **gate** (step 4).

**Stop** when a round is **clean** (no `Strong` or `Worth exploring` candidate; its `Speculative` ones go unapplied, into the summary), or after the last allowed round. A round with a stronger candidate applies all of its candidates, `Speculative` included.

## 3. Review rounds (up to 3, or the rounds option)

Invoke `/code-review` once to load its process, then run that process each round with these overrides:

- **Diff**: `git diff <base>` (two-dot against the working tree) plus the work's untracked files, in place of `<fixed-point>...HEAD`.
- **Spec**: the one from step 1; never ask the user. Spec skipped → run Standards only.
- **Spec axis judges behaviour, not location.** Add to its brief: _a ticket naming a file, class or method describes the result, not a rule; code living elsewhere with the right behaviour is no finding._
- **Both reviewers get the change log** and its conflict rule.
- **No user**: skip its aggregation step and any line telling the user to run a setup skill; the two reports go straight to the fixer. Missing issue-tracker docs → find the spec as in step 1.

Hand every finding to a **fixer**, then run the **gate**.

**Stop** when a round has no findings, when its fixer made no edits (only skips and conflicts), or after the last allowed round.

## 4. Gate (after every fixer)

Run the gate commands yourself, output to a log file in `$TMPDIR` (never in the repo, or save points pick it up), read only the exit codes and, on failure, the tail of the log.

- **Green** → take a new save point, append the fixer's change-log lines, continue.
- **Red** → one more fixer with the failing output. Green now → as above. Still red → restore the last save point, skip any remaining arch or review steps, go to step 5, and record what was undone and why for the summary.

## 5. Full suite (once)

Full suite option `skip` → record `Full suite: skipped` for the summary and go to step 6. Else run the full suite. Red → one fixer with the output, run again, and append its change-log lines (they go in the summary). Still red → keep the tree as is and report it red in the summary; it may predate the polish.

## 6. Summary

Take a final save point. Renumber the fixers' item ids so each kind counts from 1 in order; keep ⚠️ lines and conflicts pointing at the right ids. Change log out given → write this run's change-log lines there, with the new ids.

Then start a **writer** sub-agent. Give it: the path of `SUMMARY.md` (in this skill's folder), the slice designs (or "none"), the spec, the renumbered items, the ⚠️ lines, the Not done lines, the full-suite result, and the polish diff command `git diff <save point #0> <final save point>`. It reads the diff and the files it touches, and returns the summary exactly in that file's format: each change as before and after code in its place in the slice (or flow), with its 💬 reason.

Done when every item has its change block (✏️ items: their line) and every ⚠️ and Not done line is in. Print the summary to the user as the writer returned it.

## Fixer brief

Every fixer is a fresh sub-agent. Give it: the findings or candidates (verbatim), the change log with its conflict rule, the spec, base and gate commands, and these rules:

- Apply every arch candidate, whatever its strength, and fix every hard violation, spec finding and smell. Skip one only with a concrete reason it would make the code worse.
- Read `CODING_STANDARDS.md` or whatever the repo names for writing code, and follow it in every edit.
- Behaviour changes come only from a `behaviour vs ticket` candidate or a spec finding (moving the code toward the ticket); every other edit keeps behaviour the same.
- Run the gate commands before replying; fix what you broke.
- Leave everything uncommitted.

It replies, one line per item: `fixed` / `skipped: <reason>` / `conflict: <which change-log entry>`. For each fix it also returns a change-log line and the summary item: id, short title, tag with its `Ticket:` / `Rule:` / `Smell:` quote, files and methods changed, and the 💬 reason (1–2 lines: what was wrong, then what the change fixes). No code: the writer takes before and after from the diff. A rename, unused import or typo returns one `✏️` line instead.
