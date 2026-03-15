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

# Check if typescript is enabled
ENABLED=$($YQ '.typescript.enabled' < "$CONFIG_FILE" | tr -d '"')
[ "$ENABLED" != "true" ] && exit 0

# Read extensions list
EXTENSIONS=$($YQ '.typescript.extensions[]' < "$CONFIG_FILE" | tr -d '"')

# Get file extension
EXT=".${FILE_PATH##*.}"

# Check if extension matches
MATCH=false
while IFS= read -r e; do
  [ "$e" = "$EXT" ] && MATCH=true && break
done <<< "$EXTENSIONS"
[ "$MATCH" = "false" ] && exit 0

# Walk up to find tsconfig.json
d=$(dirname "$FILE_PATH")
while [ "$d" != "/" ] && [ ! -f "$d/tsconfig.json" ]; do
  d=$(dirname "$d")
done
[ -f "$d/tsconfig.json" ] && { cd "$d" && npx tsc --noEmit 2>&1 | head -20 || true; }
