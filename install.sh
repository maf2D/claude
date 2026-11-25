#!/usr/bin/env bash
# Copy this setup into ~/.claude. Existing files with the same name are overwritten.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/claude" && pwd)"
DEST="$HOME/.claude"
mkdir -p "$DEST"
if [ -f "$DEST/settings.json" ]; then
  cp "$DEST/settings.json" "$DEST/settings.json.bak-$(date +%Y%m%d%H%M%S)"
fi
for item in skills commands hooks output-styles themes; do
  mkdir -p "$DEST/$item"
  cp -R "$SRC/$item/." "$DEST/$item/"
done
cp "$SRC/CLAUDE.md" "$SRC/settings.json" "$SRC/keybindings.json" "$DEST/"
chmod +x "$DEST/hooks/"*.sh
echo "Done. Restart Claude Code."
