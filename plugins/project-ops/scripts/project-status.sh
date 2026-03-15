#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-config.sh"

# Show project status grouped by Critical Path.
# Usage: project-status.sh [page-size]

if [[ -z "$PROJECT_OPS_PROJECT_NUMBER" ]]; then
  echo "project-ops: Error: project_number is not configured." >&2
  echo "  Run /project-ops:configure to set up your project board, or add project_number to .claude/project-ops.yaml" >&2
  exit 1
fi

PAGE_SIZE="${1:-100}"

gh api graphql -F page_size="$PAGE_SIZE" -f query='
query($page_size: Int!) {
  organization(login: "'"$PROJECT_OPS_ORG"'") {
    projectV2(number: '"$PROJECT_OPS_PROJECT_NUMBER"') {
      items(first: $page_size) {
        nodes {
          priority: fieldValueByName(name: "Priority") {
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
          criticalPath: fieldValueByName(name: "Critical Path") {
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
          content {
            ... on Issue {
              number title state
              blockedBy(first: 20) {
                nodes { state }
              }
            }
          }
        }
      }
    }
  }
}
' --jq '
  def blocked_status:
    if ((.content.blockedBy.nodes // []) | map(select(.state == "OPEN")) | length) > 0
    then "BLOCKED"
    else "UNBLOCKED"
    end;

  .data.organization.projectV2.items.nodes
  | group_by(.criticalPath.name // "None")
  | .[]
  | "=== \(.[0].criticalPath.name // "Uncategorized") ===",
    (sort_by(.priority.name) | .[] |
      "  \(.content.state)\t\(.priority.name // "-")\t\(blocked_status)\t#\(.content.number)\t\(.content.title)"
    ),
    ""
'
