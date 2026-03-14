# Merge PRs — Generalized Plugin Design

**Date:** 2026-03-14
**Status:** Approved

## Scope

### Drop
- PR #4 (`k8s-deploy`) — close without merging. Contains project-specific Vault paths, directory conventions, and scripts that cannot be generalized.

### Merge (with changes)
- PR #1: `pr-feedback-sweep`
- PR #2: `web-quality` (remove hookify files/rules)
- PR #3: `code-guards` (replace hardcoded patterns with config)
- PR #5: `adr`
- PR #6: `dotnet-quality`

---

## Config Pattern

All configurable plugins follow a single consistent pattern.

### Per-project config location

```
{project_root}/.claude/{plugin-name}/config.yaml
```

### Default config (shipped with plugin)

```
$CLAUDE_PLUGIN_ROOT/defaults/config.yaml
```

### Bootstrap behavior

Asserted on every hook run — not documented as agent instructions. If the project config does not exist, the hook copies the shipped defaults:

```bash
CONFIG_DIR="$CLAUDE_PROJECT_DIR/.claude/{plugin-name}"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$CONFIG_DIR"
  cp "$CLAUDE_PLUGIN_ROOT/defaults/config.yaml" "$CONFIG_FILE"
fi
```

### yq resolution

Resolved inline in each hook (hooks are self-contained, no shared script dependency):

```bash
if command -v yq >/dev/null 2>&1; then
  YQ="yq"
elif command -v docker >/dev/null 2>&1; then
  YQ="docker run --rm -i mikefarah/yq"
else
  echo "Warning: yq not found and docker not available. Install yq: https://github.com/mikefarah/yq" >&2
  exit 0
fi
```

Hooks always exit 0 if yq is unavailable — they warn but never block Claude.

---

## Per-Plugin Config Schemas

### code-guards

**File:** `.claude/code-guards/config.yaml`

```yaml
guards:
  env_files:
    enabled: true
    patterns:
      - "*.env"
      - "*.env.*"
      - "*secrets*"
      - "*.local"
  generated_code:
    enabled: true
    patterns:
      - "*/Generated/*"
      - "*/obj/*"
      - "*/bin/*"
      - "*/dist/*"
      - "*/build/*"
  lock_files:
    enabled: true
    patterns:
      - "*/yarn.lock"
      - "*/package-lock.json"
      - "*/pnpm-lock.yaml"
      - "*/Cargo.lock"
      - "*/go.sum"
      - "*/poetry.lock"
  shell_scripts:
    shellcheck_enabled: true
    shellcheck_severity: warning
```

Hooks read the pattern lists at runtime via yq. If a guard's `enabled` flag is false, that hook exits 0 immediately.

### web-quality

**File:** `.claude/web-quality/config.yaml`

```yaml
eslint:
  enabled: true
  extensions: [".ts", ".tsx", ".js", ".jsx"]
typescript:
  enabled: true
  extensions: [".ts", ".tsx"]
jest:
  enabled: true
  extensions: [".ts", ".tsx"]
```

No hookify rules — removed entirely from PR #2.

### dotnet-quality

**File:** `.claude/dotnet-quality/config.yaml`

```yaml
format:
  enabled: true
  sln_discovery_depth: 2
```

### adr

**File:** `.claude/adr/config.yaml`

```yaml
adr_directory: "docs/adr"
ddr_directory: "docs/ddr"
numbering_format: "%04d"
```

### pr-feedback-sweep

**File:** `.claude/pr-feedback-sweep/config.yaml`

```yaml
max_prs: 30
skip_bots: true
```

---

## pr-feedback-sweep Command Targeting

Three modes resolved from arguments passed to the slash command:

| Invocation | Behavior |
|---|---|
| `/pr-feedback-sweep` | Auto-detect PR for current branch; prompt user to scan all if no PR found |
| `/pr-feedback-sweep --all` | Scan all open PRs (up to `max_prs` from config) |
| `/pr-feedback-sweep 123 456` | Scan specific PR numbers only |

**Current-branch detection:**

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number -q '.[0].number')
```

If no PR is found for the current branch, the skill informs the user and asks whether to scan all open PRs or exit.

---

## Hook Implementation Notes

- Each hook is self-contained: yq resolution + config bootstrap + business logic in one command string.
- Hooks use `$CLAUDE_PROJECT_DIR` for the project root and `$CLAUDE_PLUGIN_ROOT` for the plugin installation dir.
- All hooks exit 0 on non-fatal conditions (missing tool, disabled guard, file extension mismatch) so they never block Claude unexpectedly.
- Pattern matching in hooks uses shell `case` statements reading values from yq-parsed config arrays.

---

## What Changes Per PR

| PR | Changes from original |
|---|---|
| #1 pr-feedback-sweep | Add config bootstrap; update command for 3-mode targeting |
| #2 web-quality | Remove hookify files/rules; replace hardcoded extensions with config |
| #3 code-guards | Replace hardcoded patterns with config read via yq |
| #5 adr | Add config for directory paths and numbering format |
| #6 dotnet-quality | Add config for format enabled/depth |
| #4 k8s-deploy | Close PR, do not merge |
