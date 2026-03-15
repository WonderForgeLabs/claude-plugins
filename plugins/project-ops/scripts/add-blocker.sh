#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-config.sh"

# Add a native "blocked by" relationship between two issues.
# Usage: add-blocker.sh <blocked-issue> <blocking-issue>
# Example: add-blocker.sh 788 786  (788 is blocked by 786)

if [[ $# -lt 2 ]]; then
  echo "project-ops: Usage: $0 <blocked-issue-number> <blocking-issue-number>" >&2
  echo "  Sets <blocked> as blocked by <blocking>" >&2
  exit 1
fi

for arg in "$1" "$2"; do
  if ! [[ "$arg" =~ ^[0-9]+$ ]]; then
    echo "project-ops: Error: issue number must be numeric, got '$arg'" >&2
    exit 1
  fi
done

BLOCKED_NID=$(gh api "repos/$PROJECT_OPS_OWNER_REPO/issues/$1" --jq .node_id)
BLOCKING_NID=$(gh api "repos/$PROJECT_OPS_OWNER_REPO/issues/$2" --jq .node_id)

if [[ -z "$BLOCKED_NID" || -z "$BLOCKING_NID" ]]; then
  echo "project-ops: Error: could not resolve issue node IDs (check issue numbers and repo access)" >&2
  exit 1
fi

gh api graphql -f query="mutation {
  addBlockedBy(input: {
    issueId: \"$BLOCKED_NID\",
    blockingIssueId: \"$BLOCKING_NID\"
  }) { issue { number title } }
}" --jq '.data.addBlockedBy.issue | "#\(.number) \(.title)"'

echo "  is now blocked by #$2"
