# Claude Code setup

This repo is my `~/.claude` folder. Only useful files are tracked (see `.gitignore`):
skills, commands, hooks, output styles, themes, `CLAUDE.md`, `settings.json`, `keybindings.json`.

## Auto save

A `SessionEnd` hook (`hooks/auto-commit.sh`) commits and pushes changes when a Claude session ends.
Nothing to run by hand.

## Use on a new computer

```bash
cd ~/.claude            # create it if it does not exist
git init -b main
git remote add origin git@github.com:maf2D/claude.git
git fetch origin
git reset --hard origin/main   # overwrites tracked files only
git branch -u origin/main
```
