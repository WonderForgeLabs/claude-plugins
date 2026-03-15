#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/project-config.sh"

# Interactive script to create a new GitHub Project V2 with opinionated defaults.
# Usage: bootstrap-project.sh [--org <org>] [--name <name>] [--copy-from <number>]

# ─── Parse arguments ──────────────────────────────────────────────────────────

ORG="$PROJECT_OPS_ORG"
PROJECT_NAME="${PROJECT_OPS_REPO} Board"
COPY_FROM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      ORG="$2"
      shift 2
      ;;
    --name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --copy-from)
      COPY_FROM="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--org <org>] [--name <name>] [--copy-from <number>]"
      echo ""
      echo "Options:"
      echo "  --org <org>           GitHub org (default: auto-detected '$PROJECT_OPS_ORG')"
      echo "  --name <name>         Project name (default: '$PROJECT_NAME')"
      echo "  --copy-from <number>  Copy field/view structure from existing project"
      exit 0
      ;;
    *)
      echo "project-ops: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

echo "project-ops: Creating project '$PROJECT_NAME' for org '$ORG'..."

# ─── Helper: run GraphQL ─────────────────────────────────────────────────────

gql() {
  gh api graphql "$@"
}

# ─── Get org node ID ──────────────────────────────────────────────────────────

ORG_ID="$(gql -f query="{ organization(login: \"$ORG\") { id } }" --jq '.data.organization.id')"
if [[ -z "$ORG_ID" ]]; then
  echo "project-ops: ERROR: Could not find org '$ORG'. Check the org name and your gh auth." >&2
  exit 1
fi

# ─── Create project ──────────────────────────────────────────────────────────

echo "project-ops: Creating project..."
CREATE_RESULT="$(gql -f query="mutation {
  createProjectV2(input: {
    ownerId: \"$ORG_ID\",
    title: \"$PROJECT_NAME\"
  }) {
    projectV2 {
      id
      number
      url
    }
  }
}" --jq '.data.createProjectV2.projectV2')"

PROJECT_ID="$(echo "$CREATE_RESULT" | jq -r '.id')"
PROJECT_NUMBER="$(echo "$CREATE_RESULT" | jq -r '.number')"
PROJECT_URL="$(echo "$CREATE_RESULT" | jq -r '.url')"

echo "project-ops: Project created: #$PROJECT_NUMBER — $PROJECT_URL"

# ─── Copy from existing project (if --copy-from) ─────────────────────────────

if [[ -n "$COPY_FROM" ]]; then
  echo "project-ops: Copying field/view structure from project #$COPY_FROM..."

  SOURCE_FIELDS="$(gql -f query="
  {
    organization(login: \"$ORG\") {
      projectV2(number: $COPY_FROM) {
        fields(first: 30) {
          nodes {
            ... on ProjectV2SingleSelectField {
              name
              dataType
              options { name description color }
            }
            ... on ProjectV2IterationField {
              name
              dataType
              configuration {
                duration
                startDay
              }
            }
            ... on ProjectV2Field {
              name
              dataType
            }
          }
        }
        views(first: 20) {
          nodes {
            name
            layout
            filter
          }
        }
      }
    }
  }
  ")"

  # Create each custom field from source
  echo "$SOURCE_FIELDS" | jq -r '.data.organization.projectV2.fields.nodes[] | select(.dataType != null) | @json' | while read -r field_json; do
    field_name="$(echo "$field_json" | jq -r '.name')"
    field_type="$(echo "$field_json" | jq -r '.dataType')"

    # Skip built-in fields
    case "$field_name" in
      Title|Assignees|Status|Labels|Milestone|Repository|Linked\ pull\ requests|Reviewers|Tracks|Tracked\ by)
        continue
        ;;
    esac

    echo "project-ops:   Creating field: $field_name ($field_type)"

    case "$field_type" in
      SINGLE_SELECT)
        options="$(echo "$field_json" | jq -c '[.options[] | {name: .name, description: (.description // ""), color: .color}]')"
        gql -f query="mutation {
          createProjectV2Field(input: {
            projectId: \"$PROJECT_ID\",
            dataType: SINGLE_SELECT,
            name: \"$field_name\",
            singleSelectOptions: $(echo "$options" | jq -c '.')
          }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } }
        }" > /dev/null
        ;;
      ITERATION)
        gql -f query="mutation {
          createProjectV2Field(input: {
            projectId: \"$PROJECT_ID\",
            dataType: ITERATION,
            name: \"$field_name\"
          }) { projectV2Field { ... on ProjectV2IterationField { id name } } }
        }" > /dev/null
        ;;
      DATE)
        gql -f query="mutation {
          createProjectV2Field(input: {
            projectId: \"$PROJECT_ID\",
            dataType: DATE,
            name: \"$field_name\"
          }) { projectV2Field { ... on ProjectV2Field { id name } } }
        }" > /dev/null
        ;;
      TEXT)
        gql -f query="mutation {
          createProjectV2Field(input: {
            projectId: \"$PROJECT_ID\",
            dataType: TEXT,
            name: \"$field_name\"
          }) { projectV2Field { ... on ProjectV2Field { id name } } }
        }" > /dev/null
        ;;
    esac
  done

  # Create views from source
  echo "$SOURCE_FIELDS" | jq -r '.data.organization.projectV2.views.nodes[] | @json' | while read -r view_json; do
    view_name="$(echo "$view_json" | jq -r '.name')"
    view_layout="$(echo "$view_json" | jq -r '.layout')"

    if [[ "$view_name" == "All items" ]]; then
      continue
    fi

    echo "project-ops:   Creating view: $view_name ($view_layout)"
    gql -f query="mutation {
      createProjectV2View(input: {
        projectId: \"$PROJECT_ID\",
        name: \"$view_name\",
        layout: $view_layout
      }) { projectV2View { id } }
    }" > /dev/null
  done

  echo "project-ops: Copied fields and views from project #$COPY_FROM"
else
  # ─── Create default fields ───────────────────────────────────────────────────

  echo "project-ops: Creating custom fields..."

  echo "project-ops:   Creating field: Priority"
  gql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$PROJECT_ID\",
      dataType: SINGLE_SELECT,
      name: \"Priority\",
      singleSelectOptions: [
        {name: \"P0 - Critical Path\", description: \"Must be done for launch\", color: RED},
        {name: \"P1 - High\", description: \"Important, schedule soon\", color: ORANGE},
        {name: \"P2 - Medium\", description: \"Normal priority\", color: YELLOW},
        {name: \"P3 - Low\", description: \"Nice to have\", color: GREEN},
        {name: \"P4 - Future\", description: \"Backlog / someday\", color: BLUE}
      ]
    }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } }
  }" > /dev/null

  echo "project-ops:   Creating field: Critical Path"
  gql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$PROJECT_ID\",
      dataType: SINGLE_SELECT,
      name: \"Critical Path\",
      singleSelectOptions: []
    }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } }
  }" > /dev/null

  echo "project-ops:   Creating field: Sprint"
  gql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$PROJECT_ID\",
      dataType: ITERATION,
      name: \"Sprint\"
    }) { projectV2Field { ... on ProjectV2IterationField { id name } } }
  }" > /dev/null

  echo "project-ops:   Creating field: Start Date"
  gql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$PROJECT_ID\",
      dataType: DATE,
      name: \"Start Date\"
    }) { projectV2Field { ... on ProjectV2Field { id name } } }
  }" > /dev/null

  echo "project-ops:   Creating field: Target Date"
  gql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$PROJECT_ID\",
      dataType: DATE,
      name: \"Target Date\"
    }) { projectV2Field { ... on ProjectV2Field { id name } } }
  }" > /dev/null

  echo "project-ops:   Creating field: Design Doc"
  gql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$PROJECT_ID\",
      dataType: TEXT,
      name: \"Design Doc\"
    }) { projectV2Field { ... on ProjectV2Field { id name } } }
  }" > /dev/null

  # ─── Create default views ────────────────────────────────────────────────────

  echo "project-ops: Creating views..."

  FIELDS_JSON="$(gql -f query="
  {
    node(id: \"$PROJECT_ID\") {
      ... on ProjectV2 {
        fields(first: 30) {
          nodes {
            ... on ProjectV2Field { id name }
            ... on ProjectV2SingleSelectField { id name }
            ... on ProjectV2IterationField { id name }
          }
        }
      }
    }
  }
  ")"

  _field_id() {
    echo "$FIELDS_JSON" | jq -r ".data.node.fields.nodes[] | select(.name == \"$1\") | .id"
  }

  PRIORITY_FID="$(_field_id "Priority")"
  CRITICAL_PATH_FID="$(_field_id "Critical Path")"
  SPRINT_FID="$(_field_id "Sprint")"
  STATUS_FID="$(_field_id "Status")"

  echo "project-ops:   Creating view: Roadmap"
  ROADMAP_VIEW_ID="$(gql -f query="mutation {
    createProjectV2View(input: {
      projectId: \"$PROJECT_ID\",
      name: \"Roadmap\",
      layout: ROADMAP_LAYOUT
    }) { projectV2View { id } }
  }" --jq '.data.createProjectV2View.projectV2View.id')"

  if [[ -n "$CRITICAL_PATH_FID" && -n "$ROADMAP_VIEW_ID" ]]; then
    gql -f query="mutation {
      updateProjectV2View(input: {
        viewId: \"$ROADMAP_VIEW_ID\",
        groupByFields: [\"$CRITICAL_PATH_FID\"]
      }) { projectV2View { id } }
    }" > /dev/null 2>&1 || true
  fi

  echo "project-ops:   Creating view: What can I work on?"
  WORK_VIEW_ID="$(gql -f query="mutation {
    createProjectV2View(input: {
      projectId: \"$PROJECT_ID\",
      name: \"What can I work on?\",
      layout: BOARD_LAYOUT
    }) { projectV2View { id } }
  }" --jq '.data.createProjectV2View.projectV2View.id')"

  if [[ -n "$PRIORITY_FID" && -n "$STATUS_FID" && -n "$WORK_VIEW_ID" ]]; then
    gql -f query="mutation {
      updateProjectV2View(input: {
        viewId: \"$WORK_VIEW_ID\",
        sortByFields: [{fieldId: \"$PRIORITY_FID\", direction: ASC}],
        verticalGroupByFields: [\"$STATUS_FID\"]
      }) { projectV2View { id } }
    }" > /dev/null 2>&1 || true
  fi

  echo "project-ops:   Creating view: Critical Paths"
  CP_VIEW_ID="$(gql -f query="mutation {
    createProjectV2View(input: {
      projectId: \"$PROJECT_ID\",
      name: \"Critical Paths\",
      layout: TABLE_LAYOUT
    }) { projectV2View { id } }
  }" --jq '.data.createProjectV2View.projectV2View.id')"

  if [[ -n "$CRITICAL_PATH_FID" && -n "$PRIORITY_FID" && -n "$CP_VIEW_ID" ]]; then
    gql -f query="mutation {
      updateProjectV2View(input: {
        viewId: \"$CP_VIEW_ID\",
        groupByFields: [\"$CRITICAL_PATH_FID\"],
        sortByFields: [{fieldId: \"$PRIORITY_FID\", direction: ASC}]
      }) { projectV2View { id } }
    }" > /dev/null 2>&1 || true
  fi

  echo "project-ops:   Creating view: Sprint Board"
  SPRINT_VIEW_ID="$(gql -f query="mutation {
    createProjectV2View(input: {
      projectId: \"$PROJECT_ID\",
      name: \"Sprint Board\",
      layout: BOARD_LAYOUT
    }) { projectV2View { id } }
  }" --jq '.data.createProjectV2View.projectV2View.id')"

  if [[ -n "$SPRINT_FID" && -n "$PRIORITY_FID" && -n "$SPRINT_VIEW_ID" ]]; then
    gql -f query="mutation {
      updateProjectV2View(input: {
        viewId: \"$SPRINT_VIEW_ID\",
        verticalGroupByFields: [\"$SPRINT_FID\"],
        sortByFields: [{fieldId: \"$PRIORITY_FID\", direction: ASC}]
      }) { projectV2View { id } }
    }" > /dev/null 2>&1 || true
  fi

  echo "project-ops:   Creating view: Dependency Order"
  DEP_VIEW_ID="$(gql -f query="mutation {
    createProjectV2View(input: {
      projectId: \"$PROJECT_ID\",
      name: \"Dependency Order\",
      layout: TABLE_LAYOUT
    }) { projectV2View { id } }
  }" --jq '.data.createProjectV2View.projectV2View.id')"

  if [[ -n "$PRIORITY_FID" && -n "$DEP_VIEW_ID" ]]; then
    gql -f query="mutation {
      updateProjectV2View(input: {
        viewId: \"$DEP_VIEW_ID\",
        sortByFields: [{fieldId: \"$PRIORITY_FID\", direction: ASC}]
      }) { projectV2View { id } }
    }" > /dev/null 2>&1 || true
  fi
fi

# ─── Link repo to project ────────────────────────────────────────────────────

echo "project-ops: Linking repo $PROJECT_OPS_OWNER_REPO to project..."
REPO_ID="$(gql -f query="{ repository(owner: \"$PROJECT_OPS_ORG\", name: \"$PROJECT_OPS_REPO\") { id } }" --jq '.data.repository.id' 2>/dev/null || true)"

if [[ -n "$REPO_ID" ]]; then
  gql -f query="mutation {
    linkProjectV2ToRepository(input: {
      projectId: \"$PROJECT_ID\",
      repositoryId: \"$REPO_ID\"
    }) { repository { nameWithOwner } }
  }" > /dev/null 2>&1 || _project_ops_warn "Could not link repo (may already be linked or insufficient permissions)"
else
  _project_ops_warn "Could not find repo $PROJECT_OPS_OWNER_REPO to link"
fi

# ─── Enable built-in workflows ────────────────────────────────────────────────

echo "project-ops: Checking built-in workflows..."

WORKFLOWS_JSON="$(gql -f query="
{
  node(id: \"$PROJECT_ID\") {
    ... on ProjectV2 {
      workflows(first: 20) {
        nodes {
          id
          name
          number
          enabled
        }
      }
    }
  }
}" 2>/dev/null || true)"

if [[ -n "$WORKFLOWS_JSON" ]]; then
  echo "$WORKFLOWS_JSON" | jq -r '.data.node.workflows.nodes[] | "project-ops:   [\(if .enabled then "ON" else "OFF" end)] \(.name)"'

  AUTO_ADD_ID="$(echo "$WORKFLOWS_JSON" | jq -r '.data.node.workflows.nodes[] | select(.name == "Auto-add to project") | .id')"
  if [[ -n "$AUTO_ADD_ID" ]]; then
    echo ""
    echo "project-ops: The 'Auto-add to project' workflow exists but its repository"
    echo "project-ops: filter must be configured via the GitHub UI (the API does not"
    echo "project-ops: support setting workflow filters)."
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

WORKFLOWS_URL="https://github.com/orgs/$ORG/projects/$PROJECT_NUMBER/workflows"

echo ""
echo "project-ops: ========================================"
echo "project-ops: Project created successfully!"
echo "project-ops:   Number:    $PROJECT_NUMBER"
echo "project-ops:   URL:       $PROJECT_URL"
echo "project-ops:   Workflows: $WORKFLOWS_URL"
echo "project-ops: ========================================"
echo ""
echo "project-ops: Next steps:"
echo "  1. Add project_number: $PROJECT_NUMBER to your .claude/project-ops.yaml"
echo "  2. Configure the Auto-add workflow: $WORKFLOWS_URL"
echo "     \u2192 Click 'Auto-add to project' \u2192 Edit \u2192 Select repo '$PROJECT_OPS_OWNER_REPO'"
echo "     \u2192 Set filter (e.g. 'is:issue,pr' to add all) \u2192 Save \u2192 Enable"
echo "  3. Add Critical Path options via the GitHub UI"
echo "  4. Configure Sprint iterations"
