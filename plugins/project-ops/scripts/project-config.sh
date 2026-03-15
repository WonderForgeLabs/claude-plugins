#!/usr/bin/env bash
# project-ops: Shared configuration loader for all project-ops scripts.
# Source this file — do not execute directly.
#
# Loads config from $CLAUDE_PROJECT_DIR/.claude/project-ops.yaml (YAML),
# or auto-detects org/repo from the git remote.
#
# Requires: yq v4+ (https://github.com/mikefarah/yq)
#
# Exports:
#   PROJECT_OPS_ORG              — GitHub org or user
#   PROJECT_OPS_REPO             — repo name
#   PROJECT_OPS_OWNER_REPO       — "org/repo"
#   PROJECT_OPS_PROJECT_NUMBER   — project number (may be empty)
#   PROJECT_OPS_PROJECT_ID       — project node ID (if configured)
#   PROJECT_OPS_FIELD_PRIORITY, PROJECT_OPS_FIELD_CRITICAL_PATH,
#   PROJECT_OPS_FIELD_SPRINT, PROJECT_OPS_FIELD_START_DATE,
#   PROJECT_OPS_FIELD_TARGET_DATE, PROJECT_OPS_FIELD_DESIGN_DOC,
#   PROJECT_OPS_FIELD_STATUS, PROJECT_OPS_FIELD_PLAN_DOC
#                                — field node IDs (if configured)
#
# Helper functions (also exported):
#   project_ops_option_id <field> <name>  — get single-select option ID
#   project_ops_sprint_id [title]         — get sprint iteration ID

# Guard against running directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "project-ops: This file must be sourced, not executed." >&2
  exit 1
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────

_project_ops_warn() {
  echo "project-ops: $*" >&2
}

_project_ops_error() {
  echo "project-ops: ERROR: $*" >&2
  exit 1
}

# ─── Require yq ───────────────────────────────────────────────────────────────

if ! command -v yq >/dev/null 2>&1; then
  # Try ~/.local/bin (common install path for non-root installs)
  if [[ -x "$HOME/.local/bin/yq" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
  else
    _project_ops_error "yq is required but not found. Install: https://github.com/mikefarah/yq"
  fi
fi

# ─── Locate config file ───────────────────────────────────────────────────────

_PROJECT_OPS_CONFIG=""

if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  _candidate="$CLAUDE_PROJECT_DIR/.claude/project-ops.yaml"
  [[ -f "$_candidate" ]] && _PROJECT_OPS_CONFIG="$_candidate"
fi

if [[ -z "$_PROJECT_OPS_CONFIG" ]]; then
  _git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$_git_root" ]]; then
    _candidate="$_git_root/.claude/project-ops.yaml"
    [[ -f "$_candidate" ]] && _PROJECT_OPS_CONFIG="$_candidate"
  fi
fi

# ─── Parse config or auto-detect ──────────────────────────────────────────────

_yq() {
  yq e "$1" "$_PROJECT_OPS_CONFIG" 2>/dev/null
}

if [[ -n "$_PROJECT_OPS_CONFIG" ]]; then
  PROJECT_OPS_ORG="$(_yq '.org')"
  PROJECT_OPS_REPO="$(_yq '.repo')"
  PROJECT_OPS_PROJECT_NUMBER="$(_yq '.project_number | tostring')"
  [[ "$PROJECT_OPS_PROJECT_NUMBER" == "null" ]] && PROJECT_OPS_PROJECT_NUMBER=""

  if [[ -z "$PROJECT_OPS_ORG" || "$PROJECT_OPS_ORG" == "null" || \
        -z "$PROJECT_OPS_REPO" || "$PROJECT_OPS_REPO" == "null" ]]; then
    _project_ops_error "Config file found at $_PROJECT_OPS_CONFIG but missing org or repo"
  fi
else
  # Auto-detect from git remote
  _remote_url="$(git remote get-url origin 2>/dev/null || true)"
  [[ -z "$_remote_url" ]] && \
    _project_ops_error "No config file found and not in a git repo with an origin remote"

  if [[ "$_remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    PROJECT_OPS_ORG="${BASH_REMATCH[1]}"
    PROJECT_OPS_REPO="${BASH_REMATCH[2]}"
  else
    _project_ops_error "Could not parse org/repo from git remote: $_remote_url"
  fi

  PROJECT_OPS_PROJECT_NUMBER=""
fi

PROJECT_OPS_OWNER_REPO="${PROJECT_OPS_ORG}/${PROJECT_OPS_REPO}"

export PROJECT_OPS_ORG PROJECT_OPS_REPO PROJECT_OPS_OWNER_REPO PROJECT_OPS_PROJECT_NUMBER

# ─── Read project ID and field IDs from config ────────────────────────────────

PROJECT_OPS_PROJECT_ID=""
PROJECT_OPS_FIELD_PRIORITY=""
PROJECT_OPS_FIELD_CRITICAL_PATH=""
PROJECT_OPS_FIELD_SPRINT=""
PROJECT_OPS_FIELD_START_DATE=""
PROJECT_OPS_FIELD_TARGET_DATE=""
PROJECT_OPS_FIELD_DESIGN_DOC=""
PROJECT_OPS_FIELD_STATUS=""
PROJECT_OPS_FIELD_PLAN_DOC=""

if [[ -n "$_PROJECT_OPS_CONFIG" && -n "$PROJECT_OPS_PROJECT_NUMBER" ]]; then
  _project_id="$(_yq '.project_id // ""')"

  if [[ -n "$_project_id" && "$_project_id" != "null" ]]; then
    PROJECT_OPS_PROJECT_ID="$_project_id"
    PROJECT_OPS_FIELD_PRIORITY="$(_yq       '.fields.Priority.id // ""')"
    PROJECT_OPS_FIELD_CRITICAL_PATH="$(_yq  '.fields["Critical Path"].id // ""')"
    PROJECT_OPS_FIELD_SPRINT="$(_yq         '.fields.Sprint.id // ""')"
    PROJECT_OPS_FIELD_START_DATE="$(_yq     '.fields["Start Date"].id // ""')"
    PROJECT_OPS_FIELD_TARGET_DATE="$(_yq    '.fields["Target Date"].id // ""')"
    PROJECT_OPS_FIELD_DESIGN_DOC="$(_yq     '.fields["Design Doc"].id // ""')"
    PROJECT_OPS_FIELD_STATUS="$(_yq         '.fields.Status.id // ""')"
    PROJECT_OPS_FIELD_PLAN_DOC="$(_yq       '.fields["Plan Doc"].id // ""')"
  else
    _project_ops_warn "project-ops.yaml has no field data. Run /project-ops:configure to populate it."
  fi
elif [[ -n "$PROJECT_OPS_PROJECT_NUMBER" ]]; then
  _project_ops_warn "No project-ops.yaml found. Run /project-ops:configure to set up."
fi

export PROJECT_OPS_PROJECT_ID
export PROJECT_OPS_FIELD_PRIORITY PROJECT_OPS_FIELD_CRITICAL_PATH
export PROJECT_OPS_FIELD_SPRINT
export PROJECT_OPS_FIELD_START_DATE PROJECT_OPS_FIELD_TARGET_DATE
export PROJECT_OPS_FIELD_DESIGN_DOC PROJECT_OPS_FIELD_STATUS PROJECT_OPS_FIELD_PLAN_DOC

# ─── Helper: get option ID by field name + option name ────────────────────────
# Usage: project_ops_option_id "Priority" "P1 - High"
project_ops_option_id() {
  local field="$1" name="$2"
  [[ -z "$_PROJECT_OPS_CONFIG" ]] && return 1
  yq e ".fields[\"$field\"].options[] | select(.name == \"$name\") | .id" \
    "$_PROJECT_OPS_CONFIG" 2>/dev/null
}
export -f project_ops_option_id

# ─── Helper: get sprint iteration ID by title (or first active) ───────────────
# Usage: project_ops_sprint_id "Sprint 1: Build Chain"
#        project_ops_sprint_id   # returns first upcoming iteration
project_ops_sprint_id() {
  local title="${1:-}"
  [[ -z "$_PROJECT_OPS_CONFIG" ]] && return 1
  if [[ -n "$title" ]]; then
    yq e ".fields.Sprint.iterations[] | select(.title == \"$title\") | .id" \
      "$_PROJECT_OPS_CONFIG" 2>/dev/null
  else
    yq e ".fields.Sprint.iterations[0].id" "$_PROJECT_OPS_CONFIG" 2>/dev/null
  fi
}
export -f project_ops_sprint_id
