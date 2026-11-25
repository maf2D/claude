# Example: frontend flow

A React feature (TanStack Query + react-hook-form) that ends at an API call. It shows the frontend tree shape, a shared hook in a box, a 🧠 State change table, and the link to the backend tour.

````markdown
# 🧭 Tour: Settings → Tag pool: create a tag
Repo: offplan · `apps/operator/src/features/settings` · commit `bb40c6f` · 2026-11-13

## 1. What it is

**What it does.** A row on the Settings page with a name field, a description field and
an Add button. It sends the new tag to the API and refreshes the list.

**Problem it solves.** Staff add tags without leaving Settings. If the name is taken,
they see why under the field, not "something went wrong".

📖 **Words**
- **TanStack Query**: a library that loads server data, caches it, and loads it again when you mark it old. Each piece of data has a key, like `['tags']`.
- **Mutation**: TanStack Query's word for a request that changes data (POST, PATCH, DELETE).
- **react-hook-form**: a library that keeps form values and errors, and checks them against a zod schema.

## 2. 🗺️ Parts map

```
settings route ─▶ TagPool ─▶ NewTagForm ─▶ useCreateTag ─▶ useAppForm ─▶ createTag ─▶ POST /operator/tags
                    │                                                                       │
                    └── useTagPool (query ['tags']) ◀──── invalidate ['tags'] after success ─┘
```

- **`TagPool`** · `components/tag-pool/tag-pool.tsx` — the whole Tags section · ⚠️ shows the add row only with `organisation.tag_manage`
- **`NewTagForm`** · `components/new-tag-form/new-tag-form.tsx` — only the layout: two fields and a button
- **`useCreateTag`** · `hooks/use-create-tag.ts` — the add row's logic: schema, defaults, request, what to do after
- **`useAppForm`** · `packages/ui/src/components/form/hooks/use-app-form.ts` (shared) — react-hook-form + a TanStack mutation · ⚠️ puts an API error under the right field by itself
- **`createTag`** · `data/tag-pool-queries.ts` — `apiClient.post('/operator/tags', request)`

## 3. 🔀 Flow

### Flow A: Add button: create a tag

```
TagPool                                     🛡️ shows only with organisation.tag_manage
  └ A0. NewTagForm
      └ A1. useCreateTag
          └ useAppForm                      (form + mutation)
              ├ zod check in the browser    → error under field
              ├ createTag                   🌍 POST /operator/tags
              ├ ok  → invalidate ['tags']   → useTagPool loads again, form resets
              └ 409 → "name taken" under the name field
```

**Story.** Ann types "Premium" and clicks Add. The button shows "Adding…". On success the
list loads again and the form empties; on 409 the message shows under the name field.

🧠 **State change**
| After… | form values | `isPending` | `['tags']` cache |
|---|---|---|---|
| Ann types | `{ name: 'Premium', description: '' }` | false | 3 tags |
| clicks Add | same | **true** (button: "Adding…") | 3 tags |
| API answers 201 | **reset** to empty | **false** | **marked old → loads again → 4 tags** |

#### A0. `NewTagForm`: layout only
`new-tag-form.tsx:16` · 🚪 Ann clicks Add · ➡️ A1
📝 Draws the two fields and the Add button. All logic comes from A1.
🏁 the form on screen; submit runs A1's request

```tsx
export const NewTagForm: FC = () => {
  const creation = useCreateTag();                                        // all the logic; the component only draws → A1
  return (
    <Form form={creation}>                                                // wires submit; shows errors that belong to no field
      <FormFields<CreateTagRequest> fields={createNewTagFields(text)} />
      <Button type="submit" disabled={creation.isPending}>                // off while the request runs: no double click
        ...
```

#### A1. `useCreateTag()`: what to send and what to do after
`hooks/use-create-tag.ts:15` · ⬅️ A0 · ➡️ back-end: Tag tour, Flow A
📝 Says what to check, what to send, and what to do after a success.
🏁 201 → list loads again, form empties · 409 → "name taken" under the name field · other error → a message for the whole form
💡 **Why reload instead of adding the tag to the list by hand?** The list also shows how many Organisations use each tag, and its order comes from the API. → ADR-0013

```ts
export const useCreateTag = () => {
  const queryClient = useQueryClient();                                     // the shared cache of loaded data (TanStack Query)
  const creation = useAppForm<CreateTagRequest, Tag>({                      // joins the form and the request
    schema: createNewTagFormSchema(text),                                   // checks the form in the browser first
    defaultValues: { name: '', description: '' },
    request: createTag,                                                     // apiClient.post('/operator/tags', …) → back-end Flow A
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['tags'] });          // marks ['tags'] old; useTagPool loads again
      creation.form.reset();
    },
  });

  ┌─ useAppForm({ schema, defaultValues, request, onSuccess }) · packages/ui/…/use-app-form.ts
  │ 📝 Shared hook: joins a react-hook-form form and a TanStack mutation.
  │ 🏁 the form + isPending · puts an API error under its field by itself
  │
  │ const form = useForm({ resolver: standardSchemaResolver(schema), … });  // holds values; runs zod on them (react-hook-form)
  │ const submission = useMutation({                                        // runs request; tracks isPending (TanStack Query)
  │   mutationFn: request,
  │   onSuccess,
  │   onError: (error) => {
  │     const failure = toFieldFailure(error, messages, { ... });           // API error type → the text for one field
  │     for (const [field, fieldMessage] of failure.fieldMessages) {
  │       form.setError(field, { message: text(fieldMessage) });            // "name taken" under the name field
  │     }
  │   ...
  └─

  return creation;
};
```

## ❔ You could ask next
- How does `useTagPool` load the list, and when does it load again by itself?
- What does `toFieldFailure` do with an error it doesn't know?
````
