#!/usr/bin/env bash
# Add an issue/PR to a GitHub Projects V2 board (idempotent).
# If the item already exists, returns the existing item ID.
# Reads project ID from .claude/project-ops.yaml.
#
# Usage: add-item.sh <issue-node-id>
#
# Arguments:
#   issue-node-id  The GraphQL node ID of the issue (e.g., I_kwDO...)
#
# Output: Prints the project item ID to stdout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$REPO_ROOT/.claude/project-ops.yaml"

ISSUE_NODE_ID="${1:?Usage: add-item.sh <issue-node-id>}"
PROJECT_ID=$(yq -r '.project_id' "$CONFIG")

# Check if the issue is already on the project (paginate through all items)
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
              nodes {
                id
                content {
                  ... on Issue { id }
                  ... on PullRequest { id }
                }
              }
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
              nodes {
                id
                content {
                  ... on Issue { id }
                  ... on PullRequest { id }
                }
              }
            }
          }
        }
      }' -f projectId="$PROJECT_ID")
  fi

  # Fail loudly on GraphQL errors (auth failures, invalid project ID, etc.)
  GQL_ERRORS=$(printf '%s' "$RESPONSE" | jq -r '.errors // empty')
  if [ -n "$GQL_ERRORS" ]; then
    echo "ERROR: GraphQL query failed:" >&2
    printf '%s\n' "$GQL_ERRORS" >&2
    exit 1
  fi

  # Try to find the matching item on this page.
  # jq's select() produces no output when no node matches, which makes
  # head -n 1 return empty. The || true handles SIGPIPE from head when
  # jq closes early; genuine parse errors still print to stderr.
  ITEM_ID=$(printf '%s' "$RESPONSE" | jq -r --arg nodeId "$ISSUE_NODE_ID" '
    .data.node.items.nodes[]
    | select(.content.id == $nodeId)
    | .id
  ' | head -n 1 || true)

  if [ -n "$ITEM_ID" ]; then
    break
  fi

  # Check for more pages
  HAS_NEXT=$(printf '%s' "$RESPONSE" | jq -r '.data.node.items.pageInfo.hasNextPage // false')
  if [ "$HAS_NEXT" != "true" ]; then
    break
  fi

  AFTER_CURSOR=$(printf '%s' "$RESPONSE" | jq -r '.data.node.items.pageInfo.endCursor // ""')
  if [ -z "$AFTER_CURSOR" ]; then
    break
  fi
done

if [ -n "$ITEM_ID" ]; then
  echo "$ITEM_ID"
  exit 0
fi

# Not on the project yet — add it
ITEM_ID=$(gh api graphql -f query='
  mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemById(input: {
      projectId: $projectId
      contentId: $contentId
    }) { item { id } }
  }' -f projectId="$PROJECT_ID" -f contentId="$ISSUE_NODE_ID" \
  --jq '.data.addProjectV2ItemById.item.id')

echo "$ITEM_ID"
