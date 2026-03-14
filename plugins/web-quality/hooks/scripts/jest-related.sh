#!/usr/bin/env bash
FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0
case "$FILE_PATH" in
  *__tests__*|*.test.*|*.spec.*)
    exit 0
    ;;
  *.ts|*.tsx)
    d=$(dirname "$FILE_PATH")
    b=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
    for ext in test.ts test.tsx spec.ts spec.tsx; do
      for td in "$d/__tests__" "$d"; do
        t="$td/$b.$ext"
        if [ -f "$t" ]; then
          root="$FILE_PATH"
          while [ "$root" != "/" ]; do
            root=$(dirname "$root")
            [ -f "$root/package.json" ] && break
          done
          [ -f "$root/package.json" ] && { cd "$root" && npx jest --no-coverage --bail "$t" 2>&1 | tail -10 || true; }
          exit 0
        fi
      done
    done
    ;;
esac
