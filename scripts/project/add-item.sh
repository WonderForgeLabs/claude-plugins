#!/usr/bin/env bash
# Add an issue/PR to a GitHub Projects V2 board (idempotent).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$REPO_ROOT/.claude/project-ops.yaml"

ISSUE_NODE_ID="${1:?Usage: add-item.sh <issue-node-id>}"
PROJECT_ID=$(yq -r '.project_id' "$CONFIG")

ITEM_ID=""
AFTER_CURSOR=""

while :; do
  if [ -n "$AFTER_CURSOR" ]; then
    RESPONSE=$(gh api graphql -f query='
      query($projectId: ID!, $after: String) {
        node(id: $projectId) {
          ... on ProjectV2 {
            items(first: 100, after: $after) {
              pageInfo { hasNextPage endCursor }
              nodes { id content { ... on Issue { id } ... on PullRequest { id } } }
            }
          }
        }
      }' -f projectId="$PROJECT_ID" -f after="$AFTER_CURSOR")
  else
    RESPONSE=$(gh api graphql -f query='
      query($projectId: ID!) {
        node(id: $projectId) {
          ... on ProjectV2 {
            items(first: 100) {
              pageInfo { hasNextPage endCursor }
              nodes { id content { ... on Issue { id } ... on PullRequest { id } } }
            }
          }
        }
      }' -f projectId="$PROJECT_ID")
  fi

  GQL_ERRORS=$(printf '%s' "$RESPONSE" | jq -r '.errors // empty')
  if [ -n "$GQL_ERRORS" ]; then
    echo "ERROR: GraphQL query failed:" >&2
    printf '%s\n' "$GQL_ERRORS" >&2
    exit 1
  fi

  ITEM_ID=$(printf '%s' "$RESPONSE" | jq -r "
    .data.node.items.nodes[]
    | select(.content.id == \"$ISSUE_NODE_ID\")
    | .id
  " | head -n 1 || true)

  if [ -n "$ITEM_ID" ]; then break; fi

  HAS_NEXT=$(printf '%s' "$RESPONSE" | jq -r '.data.node.items.pageInfo.hasNextPage // false')
  if [ "$HAS_NEXT" != "true" ]; then break; fi

  AFTER_CURSOR=$(printf '%s' "$RESPONSE" | jq -r '.data.node.items.pageInfo.endCursor // ""')
  if [ -z "$AFTER_CURSOR" ]; then break; fi
done

if [ -n "$ITEM_ID" ]; then
  echo "$ITEM_ID"
  exit 0
fi

ITEM_ID=$(gh api graphql -f query='
  mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemById(input: { projectId: $projectId contentId: $contentId }) { item { id } }
  }' -f projectId="$PROJECT_ID" -f contentId="$ISSUE_NODE_ID" \
  --jq '.data.addProjectV2ItemById.item.id')

echo "$ITEM_ID"
