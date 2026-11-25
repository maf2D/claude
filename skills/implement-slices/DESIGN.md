# Slice design format

A design shows the user what the slice will create, before any code exists: every new or changed method, what it does, how it can end, and its key lines. It reads like a code tour of code not yet written. Show only the lines that matter; cut the rest to `…` or a `/* what it does */` comment.

## Parts, in order

1. **Title**: `### Slice <n>: <route or user action> — <what it does>`
2. **Tree**: the call tree in a code block. Every level, private methods marked `(private)`. Marks: 🆕 new, ✏️ changed, no mark for reused (add `(reused)` or `(<module> module, reused)` when it helps). On the right: 🛡️ permission, 🔒 transaction or row lock, 🌍 outside call (external API, or frontend → our API), `→ 409 <reason>` errors.
3. **Reuse**: one line per match with `notes.md`: `♻️ <noted piece> · reused` or `♻️ same shape as <noted piece> (Slice <n>)`, and each Owners line this slice follows. `none` when nothing matches.
4. **Story**: 2–3 short lines, one real case with a person and real values.
5. **DB change** (backend): only the schema change, one line each with why it matters (a new enum value, a new index, a new column). `none (read only)` when nothing changes. No data tables.
6. **Code**: the nested boxes (rules below).
7. **New / changed**: types, errors (with HTTP code), messages, shared pieces. One line per group.
8. **Tests**: the test names, grouped by kind (e2e, unit). These are the tests the sub-agent writes first.

Frontend adds, before New / changed:
- **UI states**: what the user sees in each state (empty, loading, success, each error).
- 🧠 **State table**, when values change while the user acts: one row per moment, changed cells in **bold**, max 4 rows.

**Foundation slice**: parts 1, 3, 5, 7 only, plus new entity fields and enum values. No tree, no boxes: there is no flow.

## Boxes

The entry (controller method, or the component that starts the action) is the top code block. Every call into our own code gets a **box** under the line that makes the call, inside the same code block. Boxes nest inside boxes.

```
  return this.renames.availabilityOf(id, slug);

  ┌─ 🆕 DomainRenameService.availabilityOf(id, slug) · domain/domain-rename.service.ts
  │ 🧱 New service: all rename logic. DomainService is already big.
  │ 📝 Loads the Project of the Domain, asks "who claims this slug", turns the claim into an answer.
  │ 🏁 free · invalid · taken + reason · 404 unknown Domain
  │ 💡 Project loads first: an unknown id is 404 even for a bad slug.
  │
  │ const project = await this.findProjectOf(id);              // the Domain's Project, or 404
  │ …
  └─
```

Each box starts with its card, then the code:
- `┌─ <mark> Class.method(args) · <file>` on top, `│ ` before each line, `└─` at the end. One empty line before and after a box.
- 🧱 **only the first time a new class appears**: what it is for, and why it is new (why not an existing class). A part moved out of another class says what changes there.
- 📝 what the method does, one or two lines.
- 🏁 every way it can end: each return kind and each error.
- 💡 a choice that looks odd, one line. Optional.
- Card lines are not code comments, so the code highlighter reads them as code. Never write `'` or a backtick in a card line: one `'` opens a string and turns the rest of the block orange. Write "the Project of the Domain", not "the Domain's Project"; "cannot", not "can't". Double quotes only in pairs on one line.

Code lines:
- Each line that matters gets a comment on its right: what it does and, when it matters, why. All comments in a block start at one column.
- One-statement callees with no call into our code (one query, one return) get no box: the comment says what they do, with their mark: `// 🆕 repo, one query: Project id + slug`.
- A small method that is a list of cases is shown as `case → result` lines, not code.
- A method already boxed earlier: its comment ends `→ see Slice 2` or `→ see R1`.
- A box over ~15 lines or at a 4th level becomes its own **section** after the main code block: `#### R1. <mark> Class.method() (private)`, then its 📝 / 🏁 / 💡 lines, then its code block with its own boxes. Its call line ends `→ R1`.

Frontend:
- A slice that changes an existing component shows only the lines it adds, with 📝 "This slice adds: …".
- JSX shows the important element and its props; styles and layout stay out.
- A request to our API ends its comment with `🌍 → Slice <n>`.

## Examples

- Backend → [`examples/backend.md`](examples/backend.md)
- Frontend → [`examples/frontend.md`](examples/frontend.md)
