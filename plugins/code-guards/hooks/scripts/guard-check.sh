#!/usr/bin/env bash
# Usage: guard-check.sh <guard_name> <block_message>
# Reads FILE_PATH from stdin (JSON via jq), checks against config patterns.
# Exits 2 (BLOCK) if file matches any pattern, exits 0 otherwise.

GUARD_NAME="$1"
BLOCK_MSG="$2"

# Read file path from stdin
FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

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

# Check if guard is enabled
ENABLED=$(cat "$CONFIG_FILE" | $YQ ".guards.${GUARD_NAME}.enabled" 2>/dev/null || true)
[ "$ENABLED" != "true" ] && exit 0

# Read patterns and check for match
PATTERNS=$(cat "$CONFIG_FILE" | $YQ ".guards.${GUARD_NAME}.patterns[]" 2>/dev/null || true)
[ -z "$PATTERNS" ] && exit 0

# Check each pattern — if file matches ANY pattern, BLOCK
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  # Use bash glob pattern matching
  # The ! (negation) logic: we block if it DOES match
  case "$FILE_PATH" in
    $pattern)
      echo "BLOCK: $BLOCK_MSG: $FILE_PATH" >&2
      exit 2
      ;;
  esac
done <<< "$PATTERNS"

# No pattern matched — allow
exit 0
