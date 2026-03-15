#!/usr/bin/env bash
# Runs shellcheck on .sh files if enabled in config.

FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# Only check .sh files
case "$FILE_PATH" in *.sh) ;; *) exit 0;; esac

# Bootstrap config
CONFIG_DIR="$CLAUDE_PROJECT_DIR/.claude/code-guards"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$CONFIG_DIR" && cp "$CLAUDE_PLUGIN_ROOT/defaults/config.yaml" "$CONFIG_FILE" || exit 0
fi
[ -f "$CONFIG_FILE" ] || exit 0

# Resolve yq
if command -v yq >/dev/null 2>&1; then
  YQ="yq"
elif command -v docker >/dev/null 2>&1; then
  YQ="docker run --rm -i mikefarah/yq"
else
  echo "Warning: yq not found and docker not available. Install yq: https://github.com/mikefarah/yq" >&2
  exit 0
fi

# Check if enabled
ENABLED=$(cat "$CONFIG_FILE" | $YQ '.guards.shell_scripts.enabled' 2>/dev/null || true)
[ "$ENABLED" != "true" ] && exit 0

SEVERITY=$(cat "$CONFIG_FILE" | $YQ '.guards.shell_scripts.shellcheck_severity' 2>/dev/null || true)
[ -z "$SEVERITY" ] && SEVERITY="warning"

[ -f "$FILE_PATH" ] || exit 0
command -v shellcheck >/dev/null 2>&1 && {
  shellcheck --severity="$SEVERITY" --format=gcc "$FILE_PATH" 2>&1 | head -50 || true
} || true
