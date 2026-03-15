#!/usr/bin/env bash

FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# Bootstrap config
CONFIG_DIR="$CLAUDE_PROJECT_DIR/.claude/web-quality"
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

# Check if jest is enabled
ENABLED=$($YQ '.jest.enabled' < "$CONFIG_FILE" | tr -d '"')
[ "$ENABLED" != "true" ] && exit 0

# Read test patterns
PATTERNS=$($YQ '.jest.test_patterns[]' < "$CONFIG_FILE" | tr -d '"')

# Check if the file IS a test file (basename matches any test_pattern glob)
BASENAME=$(basename "$FILE_PATH")
IS_TEST=false
while IFS= read -r pattern; do
  # Use bash pattern matching — convert glob pattern for case
  case "$BASENAME" in
    $pattern) IS_TEST=true; break ;;
  esac
done <<< "$PATTERNS"

DIR=$(dirname "$FILE_PATH")

if [ "$IS_TEST" = "true" ]; then
  # Run jest directly on the test file
  d="$DIR"
  while [ "$d" != "/" ] && [ ! -f "$d/package.json" ]; do
    d=$(dirname "$d")
  done
  [ -f "$d/package.json" ] && { cd "$d" && npx jest --no-coverage --bail "$FILE_PATH" 2>&1 | tail -10 || true; }
  exit 0
fi

# Not a test file — strip last extension to get the stem
STEM="${BASENAME%.*}"

# Build pattern suffixes from test_patterns (e.g. *.test.ts -> .test.ts)
SUFFIXES=()
while IFS= read -r pattern; do
  suffix="${pattern#\*}"
  SUFFIXES+=("$suffix")
done <<< "$PATTERNS"

# Search for a matching test file
TEST_FILE=""
for suffix in "${SUFFIXES[@]}"; do
  for search_dir in "$DIR" "$DIR/__tests__"; do
    candidate="$search_dir/${STEM}${suffix}"
    if [ -f "$candidate" ]; then
      TEST_FILE="$candidate"
      break 2
    fi
  done
done

[ -z "$TEST_FILE" ] && exit 0

# Walk up to find package.json
d="$DIR"
while [ "$d" != "/" ] && [ ! -f "$d/package.json" ]; do
  d=$(dirname "$d")
done
[ -f "$d/package.json" ] && { cd "$d" && npx jest --no-coverage --bail "$TEST_FILE" 2>&1 | tail -10 || true; }
