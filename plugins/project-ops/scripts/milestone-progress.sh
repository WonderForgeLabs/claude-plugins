#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-config.sh"

# Show milestone progress for the repository.
# Usage: milestone-progress.sh

gh api "repos/$PROJECT_OPS_OWNER_REPO/milestones" --jq '
  .[]
  | "\(.title)\topen: \(.open_issues)\tclosed: \(.closed_issues)\tdue: \(if .due_on then .due_on[:10] else "none" end)"
' | column -t -s $'\t'
