#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-config.sh"

# Show native blocking relationships for an issue.
# Usage: show-blockers.sh <issue-number>

if [[ $# -lt 1 ]]; then
  echo "project-ops: Usage: $0 <issue-number>" >&2
  exit 1
fi

if ! [[ "$1" =~ ^[0-9]+$ ]]; then
  echo "project-ops: Error: issue number must be numeric, got '$1'" >&2
  exit 1
fi

gh api graphql -f query="
{
  repository(owner: \"$PROJECT_OPS_ORG\", name: \"$PROJECT_OPS_REPO\") {
    issue(number: $1) {
      number
      title
      blockedBy(first: 20) {
        nodes { number title state }
      }
      blocking(first: 20) {
        nodes { number title state }
      }
      subIssues(first: 20) {
        nodes { number title state }
      }
      parent { number title }
    }
  }
}" --jq '
  .data.repository.issue |
  "Issue: #\(.number) \(.title)",
  "",
  (if .parent then "Parent: #\(.parent.number) \(.parent.title)" else empty end),
  "",
  (if (.blockedBy.nodes | length) > 0 then
    "Blocked by:",
    (.blockedBy.nodes[] | "  \(.state)\t#\(.number)\t\(.title)")
  else "Blocked by: (none)" end),
  "",
  (if (.blocking.nodes | length) > 0 then
    "Blocking:",
    (.blocking.nodes[] | "  \(.state)\t#\(.number)\t\(.title)")
  else "Blocking: (none)" end),
  "",
  (if (.subIssues.nodes | length) > 0 then
    "Sub-issues:",
    (.subIssues.nodes[] | "  \(.state)\t#\(.number)\t\(.title)")
  else empty end)
'
