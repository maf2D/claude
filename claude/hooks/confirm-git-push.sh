#!/usr/bin/env bash
# PreToolUse(Bash): force a confirmation prompt on any `git push`.
# CLAUDE.md rules are advisory; this one the agent cannot talk itself out of.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""')

# Deliberately loose: any `git ... push` in the line, so `git -C <dir> push` and
# chained commands are caught too. A false prompt costs a keypress; a miss costs a push.
if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_-])git[^;&|]*[[:space:]]push([[:space:]]|$)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "This runs `git push`. Confirm before anything leaves the machine."
    }
  }'
fi

exit 0
