#!/usr/bin/env bash
# Copy the latest skills and config from ~/.claude into this repo, then commit and push.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
SRC="$HOME/.claude"
DEST="$REPO/claude"

rsync -aL --delete --exclude synced --exclude .DS_Store "$SRC/skills/" "$DEST/skills/"
for item in commands hooks output-styles themes; do
  rsync -a --delete --exclude .DS_Store "$SRC/$item/" "$DEST/$item/"
done
cp "$SRC/CLAUDE.md" "$SRC/keybindings.json" "$DEST/"
sed "s#$HOME/.claude/#~/.claude/#g" "$SRC/settings.json" > "$DEST/settings.json"
[ -f "$HOME/.agents/.skill-lock.json" ] && cp "$HOME/.agents/.skill-lock.json" "$DEST/skill-lock.json"

cd "$REPO"
git add -A
if git diff --cached --quiet; then
  echo "No changes."
  exit 0
fi
git status --short
git commit -qm "Sync Claude setup $(date +%Y-%m-%d)"
git push
echo "Synced and pushed."
