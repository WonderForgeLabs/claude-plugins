#!/usr/bin/env bash
FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0
case "$FILE_PATH" in
  *.ts|*.tsx)
    d=$(dirname "$FILE_PATH")
    while [ "$d" != "/" ] && [ ! -f "$d/tsconfig.json" ]; do
      d=$(dirname "$d")
    done
    [ -f "$d/tsconfig.json" ] && { cd "$d" && npx tsc --noEmit 2>&1 | head -20 || true; }
    ;;
esac
