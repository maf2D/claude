---
name: asana-task
description: Create an Asana task that matches the house style of existing tasks in the same project, after showing a draft for approval.
disable-model-invocation: true
---

# Asana Task

Turn the user's request (the skill arguments, or the current conversation) into one Asana task written in the project's **house style**: the shape its existing tasks already share. Nothing is posted until the user approves the **draft**.

## 1. Find the project

Get the target project from the arguments. If none is named, call `get_me`, list the user's projects, and ask which one.

Done when you hold one project GID.

## 2. Learn the house style

Read 5–10 recent tasks from that project with `get_task` (full fields, not the list view). Prefer tasks created by the user and tasks of the same kind as the new one (bug, feature, chore). For each, note:

- Title pattern: prefix, tag, verb form, length.
- Description layout: headings, sections, checklists, links, tone, language.
- Fields: section/column, assignee, due date habits, tags, custom fields and their usual values.
- Subtasks: whether they are used, and how they are split.

Done when you can state the house style as a short list of rules, each seen in at least two tasks. A habit seen once is noise.

## 3. Show the draft

Write the new task in the house style and show it to the user as a draft:

- Title
- Description (rendered as it will look in Asana)
- Section, assignee, due date, tags, custom fields
- Subtasks, if the house style uses them
- One line: which existing tasks you modelled it on

Fill only what the request supports. Mark any field you had to guess with `(guess)`. Then ask: post it, or change something?

## 4. Revise until approved

Apply each change the user asks for and show the full draft again. Repeat until the user clearly approves ("yes", "post it", "ok").

Done when the user has approved this exact draft. Approval of an earlier version does not count.

## 5. Post

Create the task with `create_tasks`, then add subtasks if the draft has them. Reply with the task link.
