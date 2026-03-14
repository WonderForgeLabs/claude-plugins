#!/usr/bin/env bash
FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx)
    d=$(dirname "$FILE_PATH")
    while [ "$d" != "/" ] && [ ! -f "$d/package.json" ]; do
      d=$(dirname "$d")
    done
    [ -f "$d/package.json" ] && { cd "$d" && npx eslint --fix "$FILE_PATH" 2>/dev/null || true; }
    ;;
esac
