#!/usr/bin/env bash
# Auto-formats C# files using dotnet format, reading config from YAML.

FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# Only format .cs files
case "$FILE_PATH" in *.cs) ;; *) exit 0;; esac

# Bootstrap config
CONFIG_DIR="$CLAUDE_PROJECT_DIR/.claude/dotnet-quality"
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

# Check if formatting is enabled
ENABLED=$(cat "$CONFIG_FILE" | $YQ '.format.enabled' 2>/dev/null || true)
[ "$ENABLED" != "true" ] && exit 0

# Read sln discovery depth
DEPTH=$(cat "$CONFIG_FILE" | $YQ '.format.sln_discovery_depth' 2>/dev/null || true)
[ -z "$DEPTH" ] && DEPTH=2

# Find solution file
slnfile=$(find "$CLAUDE_PROJECT_DIR" -maxdepth "$DEPTH" \( -name '*.sln' -o -name '*.slnx' \) 2>/dev/null | sort | head -1)

if [ -n "$slnfile" ]; then
  dotnet format "$slnfile" --include "$FILE_PATH" --no-restore 2>/dev/null || true
else
  dotnet format --include "$FILE_PATH" --no-restore 2>/dev/null || true
fi
