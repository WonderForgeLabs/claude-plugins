#!/usr/bin/env bash
# Runs shellcheck on .sh files if enabled in config.

FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# Only check .sh files
case "$FILE_PATH" in *.sh) ;; *) exit 0;; esac

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

# Check if enabled
ENABLED=$(cat "$CONFIG_FILE" | $YQ '.guards.shell_scripts.enabled' 2>/dev/null || true)
[ "$ENABLED" != "true" ] && exit 0

SEVERITY=$(cat "$CONFIG_FILE" | $YQ '.guards.shell_scripts.shellcheck_severity' 2>/dev/null || true)
[ -z "$SEVERITY" ] && SEVERITY="warning"

[ -f "$FILE_PATH" ] || exit 0
command -v shellcheck >/dev/null 2>&1 && {
  shellcheck --severity="$SEVERITY" --format=gcc "$FILE_PATH" 2>&1 | head -50 || true
} || true
