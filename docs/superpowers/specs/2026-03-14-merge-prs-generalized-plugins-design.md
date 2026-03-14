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

### Environment variables

- `$CLAUDE_PROJECT_DIR` — root of the user's project (set by Claude Code at hook runtime)
- `$CLAUDE_PLUGIN_ROOT` — directory where the plugin is installed (set by Claude Code at hook runtime, points to the plugin's own files). This is a standard Claude Code hook variable — hooks for installed plugins receive it automatically.

### Per-project config location

```
$CLAUDE_PROJECT_DIR/.claude/{plugin-name}/config.yaml
```

### Default config (shipped with plugin)

```
$CLAUDE_PLUGIN_ROOT/defaults/config.yaml
```

### Bootstrap behavior

Asserted at the start of every hook run and at the start of every slash command — not documented as agent instructions. If the project config does not exist, copy the shipped defaults. Bootstrap failures are non-fatal (exit 0) so they never block Claude:

```bash
CONFIG_DIR="$CLAUDE_PROJECT_DIR/.claude/{plugin-name}"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$CONFIG_DIR" && cp "$CLAUDE_PLUGIN_ROOT/defaults/config.yaml" "$CONFIG_FILE" || exit 0
fi
# Guard config reads: if config is still missing after bootstrap, skip gracefully
[ -f "$CONFIG_FILE" ] || exit 0
```

If bootstrap fails (e.g. permissions error), the hook exits 0 immediately — it never falls through into config reads with a missing file.

For **slash commands** (which have no hook), bootstrap runs as the first step inside the skill/command itself before any config is read.

### yq resolution

Resolved inline in each hook and command (self-contained, no shared script dependency). All reads pipe the config file via stdin so the Docker form works identically to the native form:

```bash
if command -v yq >/dev/null 2>&1; then
  YQ="yq"
elif command -v docker >/dev/null 2>&1; then
  YQ="docker run --rm -i mikefarah/yq"
else
  echo "Warning: yq not found and docker not available. Install yq: https://github.com/mikefarah/yq" >&2
  exit 0
fi

# Usage — always pipe the file via stdin:
VALUE=$(cat "$CONFIG_FILE" | $YQ '.some.key')
# For list reads that may be empty, append "// []" to avoid null/empty-output exit codes:
ITEMS=$(cat "$CONFIG_FILE" | $YQ '.some.list[] // ""' 2>/dev/null || true)
```

Piping via stdin means `docker run --rm -i mikefarah/yq` works without any `-v` volume mount, because it reads from stdin rather than a file path argument.

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
    enabled: true
    shellcheck_severity: warning
```

All four guards have an `enabled` flag. When `enabled: false`, that hook exits 0 immediately without checking patterns. Hooks read pattern lists at runtime by piping the config file to yq. `shell_scripts` has no `patterns` key — it triggers on any `.sh` file edit and runs shellcheck at the configured severity.

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
  test_patterns: ["*.test.ts", "*.test.tsx", "*.spec.ts", "*.spec.tsx"]
```

`eslint` and `typescript` hooks trigger when the edited file's extension matches the configured list. Extension matching is case-sensitive (`.ts` does not match `.TS`).

`jest` behaves differently:
- If the saved file **is itself a test file** (its filename matches any `test_patterns` glob), Jest runs on that file directly.
- If the saved file is a **non-test source file**, the hook strips only the **last extension** to derive the basename (`Foo.component.tsx` → `Foo.component`). It then searches for a matching test file by trying all combinations of `{dir}/` and `{dir}/__tests__/` with each `test_patterns` entry (8 candidates for the default 4 patterns × 2 locations). The hook stops at the **first existing file found**, checking `{dir}/` before `{dir}/__tests__/` and patterns in config list order. `test_patterns` are matched against the filename only (not the full path). If no candidate exists, the hook exits 0 silently.
- The project root for running Jest is located by walking up from the source file's directory until a `package.json` is found.

No hookify rules — removed entirely from PR #2.

### dotnet-quality

**File:** `.claude/dotnet-quality/config.yaml`

```yaml
format:
  enabled: true
  sln_discovery_depth: 2
```

`sln_discovery_depth` is passed directly as the `find -maxdepth` argument when searching for `.sln`/`.slnx` files under `$CLAUDE_PROJECT_DIR`. A value of `2` means `find "$CLAUDE_PROJECT_DIR" -maxdepth 2 -name '*.sln' -o -name '*.slnx'`, which descends at most 2 directory levels below the project root. If multiple solution files are found, the first result is used. If none are found, `dotnet format` runs without `--sln` (formats the file directly). If `enabled: false`, the hook exits 0 immediately.

### adr

**File:** `.claude/adr/config.yaml`

The `adr` plugin handles two record types:

- **ADR (Architecture Decision Record)** — technical/architectural decisions
- **DDR (Domain Decision Record)** — domain model or business logic decisions

```yaml
adr_directory: "docs/adr"
ddr_directory: "docs/ddr"
numbering_format: "%04d"
```

`numbering_format` is a `printf`-style format string applied to the auto-incremented record number (e.g. `%04d` → `0001`, `0002`). No validation is performed — invalid format strings (e.g. `%s`) degrade silently to whatever `printf` produces.

The skill reads these paths at runtime so teams can place records wherever their project conventions require.

### pr-feedback-sweep

**File:** `.claude/pr-feedback-sweep/config.yaml`

```yaml
max_prs: 30
skip_bots: true
bot_usernames: []
```

Bootstrap runs as the first step of the skill (slash command, not a hook). `max_prs` caps how many open PRs are fetched in `--all` mode. `skip_bots` filters out comments from a hardcoded list of known bot accounts: `github-actions[bot]`, `copilot`, `dependabot[bot]`, `renovate[bot]`, `codecov[bot]`, `github-advanced-security[bot]`. `bot_usernames` is an additional list for project-specific bots not in the hardcoded set — entries here are merged with the hardcoded list (not a replacement). Set `skip_bots: false` to disable all bot filtering.

---

## pr-feedback-sweep Command Targeting

Three modes resolved from arguments passed to the slash command:

| Invocation | Behavior |
|---|---|
| `/pr-feedback-sweep` | Auto-detect PR for current branch; prompt user to scan all if no PR found |
| `/pr-feedback-sweep --all` | Scan all open PRs (up to `max_prs` from config) |
| `/pr-feedback-sweep 123 456` | Scan specific PR numbers only |
| `/pr-feedback-sweep --all 123` | Explicit PR numbers override `--all`; same as `/pr-feedback-sweep 123` — `max_prs` does not apply |

**Current-branch detection:**

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number -q '.[0].number')
```

If no PR is found for the current branch, the skill informs the user and asks whether to scan all open PRs or exit.

---

## Hook Implementation Notes

- Each hook is self-contained: yq resolution + config bootstrap + business logic in one command string.
- Hooks use `$CLAUDE_PROJECT_DIR` for the project root and `$CLAUDE_PLUGIN_ROOT` for the plugin installation dir — both set by Claude Code at runtime.
- All hooks exit 0 on non-fatal conditions (missing tool, disabled guard, file extension mismatch) so they never block Claude unexpectedly.
- Config reads always pipe the file to yq via stdin (`cat "$CONFIG_FILE" | $YQ ...`) so native and Docker yq behave identically.

---

## What Changes Per PR

| PR | Changes from original |
|---|---|
| #1 pr-feedback-sweep | Add config + bootstrap in skill; update command for 3-mode targeting |
| #2 web-quality | Remove hookify files/rules; replace hardcoded extensions with config; fix jest to use test_patterns |
| #3 code-guards | Replace hardcoded patterns with config read via yq; add enabled flag to shell_scripts guard |
| #5 adr | Add config for ADR/DDR directory paths and numbering format |
| #6 dotnet-quality | Add config for format enabled/sln_discovery_depth |
| #4 k8s-deploy | Close PR, do not merge |
