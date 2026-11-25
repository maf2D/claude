---
description: Switch to dev branch and pull latest changes
allowed-tools: Bash(git status:*), Bash(git checkout:*), Bash(git switch:*), Bash(git pull:*), Bash(git fetch:*), Bash(git branch:*)
---

Switch the current project to the `dev` branch and pull all changes.

1. Run `git status --porcelain`. If there are uncommitted changes, stop and tell the user. Do not stash or discard anything.
2. Run `git fetch --all --prune`.
3. Run `git switch dev`. If no local `dev` exists, `git switch` creates it from `origin/dev`.
4. Run `git pull`.
5. Report in one short line: branch name and what changed (e.g. "on dev, 5 new commits" or "on dev, already up to date"). If any step fails, show the error.
