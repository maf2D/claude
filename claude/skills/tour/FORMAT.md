# Tour format

The tour is **dense**: the code carries the explanation in one-line comments on its right, and every other part stays short. A reader scans the code and the comments together, top to bottom.

## Parts, in order

| Part | module | flow | diff |
|---|---|---|---|
| `# 🧭 Tour: <name>` + header line | ✓ | ✓ | ✓ |
| `## 1. What it is` | ✓ | short | the change, short |
| `## 2. 📦 Data` | when it has data | | when data changed |
| `## 3. 🗺️ Parts map` | ✓ | | the touched parts |
| `## 4. 🔀 Flows` | every flow | the one flow | touched flows |
| `## ❔ You could ask next` | ✓ | ✓ | ✓ |

Number the parts a tour has 1, 2, 3… in this order; a **flow** tour has `## 1. What it is` and `## 2. 🔀 Flow`.

**Back-end and front-end in one tour**: split the whole tour into two halves, back-end first. `What it is` stays shared at the top. Each half then has its own parts, under an H1 header with a divider above it:

```markdown
# 🧭 Tour: …
## 1. What it is          (shared: both sides, all 📖 Words)

---
# ⚙️ BACK-END
## 2. 📦 Data
## 3. 🗺️ Parts map         (back-end parts only)
## 4. 🔀 Flows             (Flow A, B, …)

---
# 🖥️ FRONT-END
## 5. 🗺️ Parts map         (front-end parts only)
## 6. 🔀 Flows             (letters go on: Flow F, G, …)

---
## ❔ You could ask next
```

**Header line**: `Repo: <repo> · <path> · commit <short hash> · <date>` (a **diff**: `Repo: <repo> · <n> files · base <branch> · commit … · <date>`), so the reader sees when the tour is old.

### 1. What it is
- **What it does.** 2–3 sentences, in user terms ("Staff keep one shared list of tags").
- **Problem it solves.** What was hard or broken without it, as one real case. 2–3 sentences.
- **What it doesn't do**, when a near thing lives elsewhere. Up to 3 bullets.
- 📖 **Words**: each project word (from `CONTEXT.md`) and each technical word a beginner may not know, that the tour uses. One line each.

### 2. 📦 Data
Per table: one line on what a row is, then 2–3 example rows with real values. Columns: only those the tour talks about; a column that is empty in every row is left out. A change over time → one table with a `when` column (🔴 before / 🟢 after), changed cells in **bold**. Then one line per rule the rows show. No tables → the data the module moves (a payload, the JSON on the wire).

### 3. 🗺️ Parts map
- A diagram: plain text boxes and arrows in a code block, max ~12 lines.
- Then one bullet per part: `` - **`Name`** 🆕 · `file` — what it does `` (the mark only in a diff). Add ` · ⚠️ <fact>` only for a surprise true for this part alone (returns `null` instead of throwing; answers 204).
- Up to 2 🧩 boxes for module-wide ideas after the parts.

### 4. 🔀 Flows
One `### Flow <letter>: <entry>: <what it does>` per flow. The entry is the route (`POST /operator/tags`), the page, or what starts it (`app boot`, `called by ProjectService`). Flows that start outside HTTP are flows too. A flow with more than ~8 steps → split it into two flows.

Each flow, in order:
1. **Tree**: the call tree in a code block. Every level, private methods marked `(private)`. The line where a step starts gets its id in front (`A1.`). Icons and `→ 409 <reason>` on the right.
2. **Story.** 2–3 short lines: the flow as one real case with a person ("Bob signs up as Acme…").
3. 🗄️ **DB change**: only when the flow writes data. A table already in **📦 Data** → one line pointing to it plus what else changes.
4. **Steps**: one per step id in the tree (rules below).

## Step rules

A step is the entry (controller, page, component), each method the tree gives an id, and each box too big to stay a box.

**Title, then the location line, then the card, then the code:**

```markdown
#### 🆕 B1. `DomainRenameService.rename()`: save, then attach the route
`domain/domain-rename.service.ts:74` · ⬅️ B0 · ➡️ B2, B4
📝 Saves the rename in one transaction, then asks Cloudflare for the new route.
🏁 the renamed Domain · 404 domain-not-found · 409 slug-taken / slug-held
💡 **Why Cloudflare after the commit?** So no DB connection waits on an outside call. → BACKEND_STANDARDS.md
```

The location line: `file:line`, then where the step sits: `🚪 <entry>` for the first step, `⬅️ <step id>` for the others; then `➡️ <step ids>` for the next steps, when there are any. Add `(from the <x> module)` for another module's code.

**Code**: the real code, cut to what matters for this flow. The signature line is always kept. Cut bodies become `…` or `/* what it does */`. About 15 lines max, not counting boxes. Then the code block ends; the next thing is the next step, a 🧩 or a 🧠.

### The card

Every step and every box opens with a card: short lines that tell the reader what the method is before they read its code. A step has its card under the location line; a box has it right under `┌─`, then one empty `│` line before the code.
- 🧱 the first time a class shows up in the tour and the Parts map has no bullet for it: what the class is for. Why it is its own class only when a source says so.
- 📝 what the method does, 1–2 lines.
- 🏁 every way it can end: each kind of return, and each error with its HTTP code (`409 tag-name-taken`). For the last step of a flow, the returns say where the result goes (`201 the new Tag as JSON`).
- 💡 **Why …?** a choice that looks odd, 1–2 lines, ending `→ ADR-<n>` or `→ comment in <file>`. Optional, at most one per card.

A small method that is only a list of cases is shown as `case → result` lines in its card, with no code.

### Comments

Each line that matters gets a comment on its right that tells what the line does and, when it matters, why: `// <what it finds or decides>; <why the flow needs it>`. Aim for 40–70 characters: a full short sentence a reader understands without the code.

**One column per code block.** Every comment sits on the same line as the code it describes, and all comments in a block start at one column: 2 spaces after the longest code line (box headers `┌─ …` and card lines don't count). Write each comment after its code with any spacing; `scripts/align-comments.py` (SKILL.md step 3) moves them to that column.
- A comment over ~70 characters → it goes on 2 lines. The second line is a line of its own with only the comment, right under the first; it never shares a line with code like `}`. Max 2 lines; more → the card's 💡.
- A `// 🔴 removed: …` mark is a comment-only line too, where the deleted code stood.

```
  if (renamed.needsRoute) {                                         // false when the Project took back its own old address
    await this.domainService.attachHost(renamed.id, renamed.host);  // asks Cloudflare for the route, after the commit → B4
                                                                    // a refusal is kept in lastError; the rename still counts
  }
```

- Say what the code does in plain words; the library or SQL goes in brackets only when it helps: `// one SQL INSERT now, returns the new id (MikroORM insert)`.
- A chain of checks: one comment per check, written as a question and its result: `// our own name (www)? → reserved`.
- An error says when it happens: `// the name is taken → 409 tag-name-taken`.
- A reference still says what the line does first: `// the Domain + its Project id, fresh from the DB → see A1`.
- The line that leads to the next step ends its comment with `→ B2`. A callback that comes back: `↩ A1`.
- A front-end flow ends at the API call with `→ back-end Flow A` (same tour) or `→ back-end: <Module> tour, Flow A`.

### Boxes

**Every call into our own code is shown**: a service, a private method, a repository, a util, another module's service, a hook. Judge a call by everything it runs, all the way down: `loadDomain(id)` is one line, but it calls `findEntryOf` (a branch) and `toDomain`, so it gets a box, with a box for `findEntryOf` inside it. The only calls with no box:
- a callee whose whole body is one statement with no call to our code (one query, one return): the comment on the call line says what that statement does;
- a method already boxed earlier in the tour: its comment ends `→ see B4` (the step id where its box is). Each method's code appears **once** per tour.

A box is the callee's code, inside the same code block, under the call:

```
const project = await this.findProjectOf(id);              // the Project, or 404 domain-not-found

┌─ findProjectOf(id) (private) · rename.service.ts:89
│ 📝 Domain id → its Project's id and current slug.
│ 🏁 the Project · 404 domain-not-found
│
│ const domain = await this.domains.findRenamable(id);     // Domain + its Project id, fresh from DB
│
│   ┌─ DomainRepository.findRenamable(id) · domain.repository.ts:40
│   │ return this.em.findOne(Domain, { id }, { refresh: true }); // reads the DB, skips the cache
│   └─
│
│ if (!domain) throw new DomainNotFoundException();        // → 404 domain-not-found
└─
```

- `┌─ Class.method() · file:line` on top, then the card, then `│ ` before each code line, `└─` at the end. One empty line before `┌─` and after `└─`.
- The box goes right after the **last line of the statement** that makes the call. A call inside a callback or a multi-line argument → the box goes after the line that closes it (`});`), at the indent of that statement.
- A box is always inside the code block it belongs to. The space under a code block holds only 🧩 and 🧠 parts.
- Boxes go inside boxes, indented one more step, up to 3 levels. A box over ~12 lines or at a 4th level becomes its own step; its call line ends `→ B3`.

### Extras, under a step's code block
- 🧩 **New idea: <name>**: 3–5 lines for a hidden project pattern the code depends on (a global guard, a callback, errors that become HTTP answers by themselves). Ends with the file or ADR. Each idea once per tour.
- 🧠 **State change**: a small table when code keeps data in memory that changes across calls (React state, a cache, a `Map`): one row per moment, changed cells in **bold**, max 4 rows.

## Tree icons

| Icon | Meaning |
|---|---|
| 🛡️ | needs a permission (name it) |
| 🌐 | public, no login |
| 🚦 | rate limit |
| 🔒 | transaction (or joins one) |
| 🌍 | outside call: an external API, or the frontend calling our API |
| ✉️ | email |
| ⏰ | runs outside the request: boot, cron, timer, listener |
| `→ 409 <reason>` | an error this step can throw |

## diff marks

In a **diff** tour, tree lines, parts, step titles and boxes get 🆕 (new) or ✏️ (changed). Unchanged steps stay in the tree for context, with no step of their own.

A ✏️ step shows its code once, as it is now, with a mark at the end of each changed comment:
- `🟢` new or changed line: `// 🟢 retires the old host first`
- `🔴 was: <old code>` when a line replaced another and the old one matters: `// 🔴 was: markActive(id, routeId)`

Old lines that were deleted and matter go as one `// 🔴 removed: <old code>` comment line where they stood.

## ❔ You could ask next
2–3 questions that go one level deeper or into the next module.
