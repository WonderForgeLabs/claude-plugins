#!/usr/bin/env bash
# Query sprint iterations from a GitHub Projects V2 iteration field.
# Reads sprint field ID from .claude/project-ops.yaml.
#
# Usage: get-iterations.sh
#
# Output: JSON array of iterations with id, title, startDate, duration.
#
# Example output:
#   [
#     {"id":"c34cbb04","title":"Sprint 2","startDate":"2026-03-03","duration":14},
#     {"id":"4ac3a8a5","title":"Sprint 3","startDate":"2026-03-17","duration":14}
#   ]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$REPO_ROOT/.claude/project-ops.yaml"

FIELD_ID=$(yq -r '.fields.Sprint.id' "$CONFIG")

gh api graphql -f query="
  query(\$fieldId: ID!) {
    node(id: \$fieldId) {
      ... on ProjectV2IterationField {
        name
        configuration {
          iterations {
            id
            title
            startDate
            duration
          }
        }
      }
    }
  }" -f fieldId="$FIELD_ID" \
  --jq '.data.node.configuration.iterations'
