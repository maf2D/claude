# Example: frontend slice

One user action on a page that already exists from an earlier slice. It shows "this slice adds", a hook box with a util box inside it, a component box, UI states and a 🧠 state table.

````markdown
### Slice 3: type a new slug → see if it is free            needs: 1

```
DomainRenameForm (from Slice 2)                      shows the input
  ├ 🆕 useRenameSlugCheck(domainId, currentSlug, typed)
  │    ├ useDebouncedValue (ui, reused)
  │    ├ 🆕 checkRenameSlug(domainId, slug)          🌍 → Slice 1
  │    └ 🆕 slugCheckOf (util)
  └ 🆕 SlugCheck({ check })                          the pill next to the input
```

**Story.** Ann types "harbour" in the box. 300ms after she stops, the page asks the API.
"harbour" belongs to another Project → a red pill "Used by another Project".
She types "harbour-bay" → green pill "Available".

```tsx
// ✏️ DomainRenameForm · domain-rename/components/domain-rename-form/domain-rename-form.tsx
// 📝 This slice adds: watch the slug input, ask for the check, show the pill.
// 🏁 Pill next to the input · rename button stays off until the check says "free" (used in Slice 5)

const slug = useWatch({ control: rename.form.control, name: 'slug' });  // the input's value on every key
const check = useRenameSlugCheck(domainId, currentSlug, slug);

  ┌─ 🆕 useRenameSlugCheck(domainId, currentSlug, typed) · domain-rename/hooks/use-rename-slug-check.ts
  │ 📝 Turns the typed text into one check value. Asks the API only when typing stops.
  │ 🏁 SlugCheck (free · invalid · unchanged · reserved · project · held · checkout) · null = show nothing
  │
  │ const settled = useDebouncedValue(typed.trim(), 300);              // waits 300ms: "harbour" asks once, not 7 times
  │ const isAsked = settled !== '' && settled !== currentSlug;         // empty or same slug → no request
  │
  │ const { data } = useQuery({
  │   queryKey: ['rename-slug-availability', domainId, settled],       // own key: reloading Domains doesn't re-ask
  │   queryFn: () => checkRenameSlug(domainId, settled),               // 🆕 data fn: GET …/slug-availability 🌍 → Slice 1
  │   enabled: isAsked,
  │ });
  │
  │ if (slug === currentSlug) return SLUG_UNCHANGED;                   // answered here, no request
  │ if (!isAsked || settled !== slug || !data) return null;            // still typing, or old answer for old text
  │ return slugCheckOf(data);
  │
  │   ┌─ 🆕 slugCheckOf(response) · domain-rename/util/slug-check-of.ts
  │   │ 📝 API answer → one word for the pill.
  │   │ taken → its takenReason (project if missing) · else → availability (free / invalid)
  │   └─
  └─

<SlugCheck check={check} />

  ┌─ 🆕 SlugCheck({ check }) · domain-rename/components/slug-check/slug-check.tsx
  │ 📝 A pill: green for free, red with the reason for anything else.
  │ 🏁 nothing when check is null
  │
  │ if (!check) return null;
  │ <Badge tone={isFree ? 'normal' : 'destructive'} shape="pill">
  │   <FormattedMessage id={check === Invalid
  │     ? 'form.field.invalid_slug'                                    // reused message
  │     : `domainRename.check.${check}`} />                            // 🆕 one en.json message per reason
  │ </Badge>
  └─

const isReady = check === SlugAvailability.Free && rename.isValid;     // Slice 5 uses this for the button
```

**UI states**
- empty input → nothing
- typing / loading → nothing
- free → green "Available"
- taken → red pill with the reason · invalid → red "invalid slug" · same slug → "unchanged"

🧠 **State while Ann types** (currentSlug = harbour-view)

| moment               | typed        | settled     | request  | pill                    |
|----------------------|--------------|-------------|----------|-------------------------|
| typing "harb…"       | harb         | (old)       | none     | hidden                  |
| stops on "harbour"   | harbour      | **harbour** | **sent** | **red "project"**       |
| types "harbour-view" | harbour-view | –           | none     | **"unchanged"**         |

**New / changed**
- 🆕 types: SlugCheck (+ SLUG_UNCHANGED)
- 🆕 messages: domainRename.check.free / unchanged / reserved / project / held / checkout

**Tests**
- shows "Available" when the API says free
- shows the reason for each taken reason
- no request for empty input or the current slug
- hides an old answer while the text changed
````
