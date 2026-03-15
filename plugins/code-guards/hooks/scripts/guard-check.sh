#!/usr/bin/env bash
# Checks all enabled guards against a file path from stdin JSON.
# Exits 2 (BLOCK) if file matches any enabled guard's patterns, exits 0 otherwise.

# Read file path from stdin
FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

# Guard names and their block messages
GUARDS="env_files generated_code lock_files"
declare -A BLOCK_MSGS
BLOCK_MSGS[env_files]="Cannot edit environment/secret files"
BLOCK_MSGS[generated_code]="Cannot edit generated/build output files"
BLOCK_MSGS[lock_files]="Cannot edit lock files"

for GUARD_NAME in $GUARDS; do
  # Check if guard is enabled
  ENABLED=$(cat "$CONFIG_FILE" | $YQ ".guards.${GUARD_NAME}.enabled" 2>/dev/null || true)
  [ "$ENABLED" != "true" ] && continue

  # Read patterns and check for match
  PATTERNS=$(cat "$CONFIG_FILE" | $YQ ".guards.${GUARD_NAME}.patterns[]" 2>/dev/null || true)
  [ -z "$PATTERNS" ] && continue

  # Check each pattern — if file matches ANY pattern, BLOCK
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    # Use bash glob pattern matching
    case "$FILE_PATH" in
      $pattern)
        echo "BLOCK: ${BLOCK_MSGS[$GUARD_NAME]}: $FILE_PATH" >&2
        exit 2
        ;;
    esac
  done <<< "$PATTERNS"
done

# No pattern matched — allow
exit 0
