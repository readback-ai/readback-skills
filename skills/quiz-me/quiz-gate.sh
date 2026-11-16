#!/usr/bin/env bash
# Claude Code PreToolUse hook: offers or requires /quiz-me before `gh pr create`.
# Set QUIZ_ON_PR to off (default), ask, or require.

mode="${QUIZ_ON_PR:-off}"
case "$mode" in
  ask|require) ;;
  *) exit 0 ;;
esac

grep -Eq 'gh[[:space:]]+pr[[:space:]]+create' || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] || exit 0
short=$(git rev-parse --short HEAD 2>/dev/null) || exit 0

record="$root/comp_checks/comp_check_${branch//\//-}.md"
if [ -f "$record" ] && grep -qF "Commit: $short" "$record" && grep -q '^## Grades' "$record"; then
  exit 0
fi

if [ "$mode" = ask ]; then
  decision=ask
  reason="Quiz on this PR or move on?"
else
  decision=deny
  reason="Your settings require a quiz before this PR. Ask the developer to run /quiz-me (you can't start it), then retry."
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
