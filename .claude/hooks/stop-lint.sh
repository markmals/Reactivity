#!/usr/bin/env bash
# Stop: lint the package if anything changed since HEAD.
# Blocks the stop (decision: block) if lint fails, so the agent fixes before declaring done.
set -euo pipefail

input=$(cat)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
[[ "$stop_hook_active" == "true" ]] && exit 0

cd "$CLAUDE_PROJECT_DIR"

# Nothing changed since HEAD → nothing to lint.
git diff --quiet HEAD 2>/dev/null && exit 0

if ! output=$(mise run lint 2>&1); then
    jq -n --arg reason "Lint failures before stop:

$output" '{decision: "block", reason: $reason}'
fi

exit 0
