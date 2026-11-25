#!/usr/bin/env bash
# SessionEnd hook: commit and push changes to tracked files in ~/.claude.
cd "$HOME/.claude" || exit 0
git add -A >/dev/null 2>&1
git diff --cached --quiet && exit 0
git commit -qm "Auto sync $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1
(git push -q >/dev/null 2>&1 &)
exit 0
