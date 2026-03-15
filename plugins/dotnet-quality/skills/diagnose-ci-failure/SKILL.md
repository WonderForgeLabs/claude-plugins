---
name: diagnose-ci-failure
description: Diagnose CI pipeline failures by fetching logs, identifying known patterns, and suggesting fixes. Use when a CI run fails or user reports "CI is red".
---

# Diagnose CI Failure

Structured investigation of CI pipeline failures. Fetches logs, checks for known patterns, categorizes the failure, and suggests fixes.

## Usage

```
/diagnose-ci-failure [run-id]
```

If no run-id provided, find the latest failed run for the current branch.

## Workflow

### Step 1: Identify the Failed Run

```bash
# Detect current repo
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# If run-id not provided, find latest failed run
gh run list --repo "$REPO" --status failure --limit 5

# Get run details
gh run view <run-id> --repo "$REPO"

# Check which jobs failed
gh run view <run-id> --repo "$REPO" --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name, conclusion, steps: [.steps[] | select(.conclusion == "failure") | .name]}'
```

### Step 2: Categorize the Failure

Common CI job categories:

| Failed Job Pattern | Category | Next Step |
|-------------------|----------|-----------|
| `*build*` | Compilation error | Step 3A |
| `*test*` | Test failure | Step 3B |
| `*e2e*`, `*playwright*` | E2E failure | Step 3C |
| `*lint*`, `*format*` | Code quality | Step 3D |
| `*deploy*`, `*validate*` | Deployment issue | Step 3E |

### Step 3A: Build Failure

```bash
gh run view <run-id> --repo "$REPO" --log-failed 2>&1 | head -100
```

**Common patterns:**
- Missing using/import statements after merge
- Package version conflicts
- SDK version mismatch

### Step 3B: Test Failure

```bash
# Download test artifacts
gh run download <run-id> --repo "$REPO"

# Check for mass failures (infrastructure problem)
find . -name "*.trx" -exec grep -l "TimeoutException" {} \; 2>/dev/null

# Check for individual test failures
find . -name "*.trx" -exec grep "outcome=\"Failed\"" {} \; | head -20
```

**Known patterns:**
- **All tests timeout** → Infrastructure startup failure, check resource/service logs
- **Port collision** (`Address already in use`) → Transient, retry
- **Health check blocking** → TLS/cert issues with health check endpoints

### Step 3C: E2E Test Failure

```bash
# Download E2E artifacts
gh run download <run-id> --repo "$REPO"

# Look for screenshot evidence
find . -name "*.png" -path "*/test-results/*" 2>/dev/null
```

**Common patterns:**
- Service not ready before E2E starts
- Auth token expired
- Frontend build error
- Selector changes from UI refactor

### Step 3D: Code Quality Failure

```bash
gh run view <run-id> --repo "$REPO" --log-failed 2>&1 | grep -A5 "lint\|format\|style"
```

**Fix:** Run the linter/formatter locally and commit fixes.

### Step 3E: Deployment Validation Failure

```bash
gh run view <run-id> --repo "$REPO" --log-failed 2>&1 | head -50
```

**Common patterns:**
- Missing placeholder replacement
- Invalid YAML/manifest structure
- Container version mismatch

### Step 4: Transient vs Persistent

Before making code changes, determine if the failure is transient:

**Transient (retry):**
- Port collision (`Address already in use`)
- Network timeout to package registries
- Docker pull rate limit
- Resource startup slowness under CI load

**Persistent (needs fix):**
- Compilation errors
- Deterministic test failures (same test fails on retry)
- Missing configurations
- Broken health checks

```bash
# Retry transient failures
gh run rerun <run-id> --repo "$REPO" --failed
```

### Step 5: Report Findings

Summarize:
1. **Failed job(s)**: Which CI job failed
2. **Category**: Build / Test / E2E / Quality / Deployment / Transient
3. **Root cause**: Specific error from logs
4. **Fix**: Action to take or "retry — transient failure"

## Anti-Patterns

- **Retrying without reading logs** — Only retry after confirming the failure is transient
- **Increasing timeouts** — Masks real startup failures; always read resource logs
- **Fixing test code when ALL tests fail** — Uniform failure = infrastructure, not test code
- **Rapid polling CI status** — Use `gh run watch <run-id>` instead
