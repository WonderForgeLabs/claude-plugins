#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-config.sh"

# Show project view configurations.
# Usage: project-views.sh

if [[ -z "$PROJECT_OPS_PROJECT_NUMBER" ]]; then
  echo "project-ops: Error: project_number is not configured." >&2
  echo "  Run /project-ops:configure to set up your project board, or add project_number to .claude/project-ops.yaml" >&2
  exit 1
fi

gh api graphql -f query='
{
  organization(login: "'"$PROJECT_OPS_ORG"'") {
    projectV2(number: '"$PROJECT_OPS_PROJECT_NUMBER"') {
      views(first: 20) {
        nodes {
          name
          layout
          filter
          groupByFields(first: 5) {
            nodes {
              ... on ProjectV2SingleSelectField { name }
              ... on ProjectV2IterationField { name }
              ... on ProjectV2Field { name }
            }
          }
          sortByFields(first: 5) {
            nodes {
              field {
                ... on ProjectV2SingleSelectField { name }
                ... on ProjectV2IterationField { name }
                ... on ProjectV2Field { name }
              }
              direction
            }
          }
          verticalGroupByFields(first: 5) {
            nodes {
              ... on ProjectV2SingleSelectField { name }
              ... on ProjectV2IterationField { name }
              ... on ProjectV2Field { name }
            }
          }
        }
      }
    }
  }
}
' --jq '
  .data.organization.projectV2.views.nodes[]
  | "=== \(.name) (\(.layout)) ===",
    (if .filter then "  Filter: \(.filter)" else empty end),
    (if .groupByFields.nodes | length > 0 then "  Group by: \([.groupByFields.nodes[].name] | join(", "))" else empty end),
    (if .sortByFields.nodes | length > 0 then "  Sort: \([.sortByFields.nodes[] | "\(.field.name) \(.direction)"] | join(", "))" else empty end),
    (if .verticalGroupByFields.nodes | length > 0 then "  Columns: \([.verticalGroupByFields.nodes[].name] | join(", "))" else empty end),
    ""
'
