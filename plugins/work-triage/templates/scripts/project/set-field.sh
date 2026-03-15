#!/usr/bin/env bash
# Set a field value on a GitHub Projects V2 item.
# Reads project ID from .claude/project-ops.yaml.
#
# Usage: set-field.sh <item-id> <field-id> <value-type> <value>
#
# Arguments:
#   item-id      The project item ID (from add-item.sh)
#   field-id     The project field ID (from .claude/project-ops.yaml)
#   value-type   One of: singleSelectOptionId, iterationId, date, text, number
#   value        The value to set
#
# Examples:
#   set-field.sh PVTI_xxx PVTSSF_xxx singleSelectOptionId f75ad846
#   set-field.sh PVTI_xxx PVTIF_xxx iterationId c34cbb04
#   set-field.sh PVTI_xxx PVTF_xxx date 2026-03-08

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$REPO_ROOT/.claude/project-ops.yaml"

ITEM_ID="${1:?Usage: set-field.sh <item-id> <field-id> <value-type> <value>}"
FIELD_ID="${2:?Missing field-id}"
VALUE_TYPE="${3:?Missing value-type (singleSelectOptionId|iterationId|date|text|number)}"
VALUE="${4:?Missing value}"
PROJECT_ID=$(yq -r '.project_id' "$CONFIG")

# Build value JSON safely with jq to avoid injection.
# Numbers must not be quoted — use --argjson for numeric types.
if [ "$VALUE_TYPE" = "number" ]; then
  VALUE_JSON=$(jq -n --arg type "$VALUE_TYPE" --argjson val "$VALUE" '{($type): $val}')
else
  VALUE_JSON=$(jq -n --arg type "$VALUE_TYPE" --arg val "$VALUE" '{($type): $val}')
fi

# gh's -f flag passes value as a string, but ProjectV2FieldValue must be a
# JSON object. Build the full request body and use --input to send it.
QUERY='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: ProjectV2FieldValue!) { updateProjectV2ItemFieldValue(input: { projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: $value }) { projectV2Item { id } } }'

jq -n \
  --arg query "$QUERY" \
  --arg projectId "$PROJECT_ID" \
  --arg itemId "$ITEM_ID" \
  --arg fieldId "$FIELD_ID" \
  --argjson value "$VALUE_JSON" \
  '{query: $query, variables: {projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: $value}}' \
| gh api graphql --input - --jq '.data.updateProjectV2ItemFieldValue.projectV2Item.id'
