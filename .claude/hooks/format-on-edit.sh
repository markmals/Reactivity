#!/usr/bin/env bash
# PostToolUse: format the touched file via the root `fmt` task.
#
# The formatter choice lives in mise.toml's `fmt` task (swift-format for Swift,
# dprint for md/json/toml) — NOT here. `fmt` accepts optional file arguments
# (format just those; format the whole package when given none).
#
# Best-effort: any failure is silenced so the agent's edit isn't disrupted.
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0

(cd "$CLAUDE_PROJECT_DIR" && mise run fmt -- "$file_path") 2>/dev/null || true
exit 0
