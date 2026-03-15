#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-config.sh"

# Add a sub-issue to a parent issue.
# Usage: add-sub-issue.sh <parent-issue> <child-issue>

if [[ $# -lt 2 ]]; then
  echo "project-ops: Usage: $0 <parent-issue-number> <child-issue-number>" >&2
  exit 1
fi

for arg in "$1" "$2"; do
  if ! [[ "$arg" =~ ^[0-9]+$ ]]; then
    echo "project-ops: Error: issue number must be numeric, got '$arg'" >&2
    exit 1
  fi
done

PARENT_NID=$(gh api "repos/$PROJECT_OPS_OWNER_REPO/issues/$1" --jq .node_id)
CHILD_NID=$(gh api "repos/$PROJECT_OPS_OWNER_REPO/issues/$2" --jq .node_id)

if [[ -z "$PARENT_NID" || -z "$CHILD_NID" ]]; then
  echo "project-ops: Error: could not resolve issue node IDs (check issue numbers and repo access)" >&2
  exit 1
fi

gh api graphql -f query="mutation {
  addSubIssue(input: {
    issueId: \"$PARENT_NID\",
    subIssueId: \"$CHILD_NID\"
  }) { issue { number title } }
}" --jq '.data.addSubIssue.issue | "#\(.number) \(.title)"'

echo "  now has #$2 as sub-issue"
