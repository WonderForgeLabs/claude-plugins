#!/usr/bin/env bash
# Query sprint iterations from a GitHub Projects V2 iteration field.
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
          iterations { id title startDate duration }
        }
      }
    }
  }" -f fieldId="$FIELD_ID" \
  --jq '.data.node.configuration.iterations'
