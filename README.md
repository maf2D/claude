# Claude Code setup

My skills, commands, hooks, output style, themes and settings for Claude Code.

## Install

```bash
git clone <this-repo> ~/claude-setup
~/claude-setup/install.sh
```

The script copies everything in `claude/` into `~/.claude`. It backs up your old `settings.json` first.

## What is inside

- `claude/skills` – all skills (Matt Pocock skills are copied as real files; source list in `skill-lock.json`)
- `claude/commands` – slash commands
- `claude/hooks` – hooks (git push confirm)
- `claude/output-styles` – "Short Simple" output style
- `claude/themes` – color themes
- `claude/CLAUDE.md`, `settings.json`, `keybindings.json` – global config
