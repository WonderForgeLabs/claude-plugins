#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-config.sh"

# List all project items grouped by status.
# Usage: items-by-status.sh [limit]

if [[ -z "$PROJECT_OPS_PROJECT_NUMBER" ]]; then
  echo "project-ops: Error: project_number is not configured." >&2
  echo "  Run /project-ops:configure to set up your project board, or add project_number to .claude/project-ops.yaml" >&2
  exit 1
fi

LIMIT="${1:-100}"

gh project item-list "$PROJECT_OPS_PROJECT_NUMBER" --owner "$PROJECT_OPS_ORG" --format json --limit "$LIMIT" \
  | jq -r '.items[] | "\(.status)\t\(.priority // "-")\t\(.content.number)\t\(.content.title // .title)"' \
  | sort | column -t -s $'\t'
