#!/usr/bin/env bash
set -uo pipefail

# Smart adaptive bisect across Aspire NuGet package versions.
# Uses git worktrees for isolation — each version test runs in its own
# worktree with package versions set via sed.
# Evidence is auto-committed when bisect completes.
#
# Usage:
#   ./bisect.sh                                              # auto-detect bounds
#   ./bisect.sh --good 13.1.2-preview.1.26125.13 --bad 13.3.0-preview.1.26124.2
#   ./bisect.sh --timeout 90                                 # custom per-test timeout

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
NUGET_FLAT2="https://pkgs.dev.azure.com/dnceng/9ee6d478-d288-47f7-aacc-f6e6d082ae6d/_packaging/a54510f9-4b2c-4e69-b96a-6096683aaa1f/nuget/v3/flat2"

GOOD_VERSION=""
BAD_VERSION=""
TEST_TIMEOUT=30
SAMPLES_PER_ROUND=3

usage() {
    echo "Usage: $0 [--good VERSION] [--bad VERSION] [--timeout SECONDS]"
    echo ""
    echo "Options:"
    echo "  --good VERSION    Known good version (test passes)"
    echo "  --bad VERSION     Known bad version (test fails)"
    echo "  --timeout SECONDS Per-test timeout in seconds (default: 30)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --good) GOOD_VERSION="$2"; shift 2 ;;
        --bad) BAD_VERSION="$2"; shift 2 ;;
        --timeout) TEST_TIMEOUT="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
EVIDENCE_DIR="$REPO_ROOT/evidence/bisect-$TIMESTAMP"
WORKTREE_BASE="/tmp/bisect-worktrees-$TIMESTAMP"
mkdir -p "$EVIDENCE_DIR" "$WORKTREE_BASE"

echo "=== Aspire Version Bisect ==="
echo "Evidence: $EVIDENCE_DIR"
echo "Worktrees: $WORKTREE_BASE"
echo "Timeout: ${TEST_TIMEOUT}s per test"
echo ""

# --- Fetch all available versions (newest first from API) ---
echo "Fetching available versions from NuGet feed..."
VERSIONS_TMP=$(mktemp)
trap "rm -f $VERSIONS_TMP" EXIT
curl -sf "${NUGET_FLAT2}/aspire.hosting.testing/index.json" > "$VERSIONS_TMP" || {
    echo "ERROR: Failed to fetch versions from NuGet feed"
    exit 1
}
ALL_VERSIONS=$(python3 -c "import json; f=open('${VERSIONS_TMP}'); print('\n'.join(json.load(f)['versions']))") || {
    echo "ERROR: Failed to parse versions JSON"
    exit 1
}

# Filter to 13.x only — older versions target net9.0 and won't build with net10.0
ALL_VERSIONS=$(echo "$ALL_VERSIONS" | grep '^13\.')
TOTAL_VERSIONS=$(echo "$ALL_VERSIONS" | wc -l)
FIRST_VERSION=$(echo "$ALL_VERSIONS" | head -1)
LAST_VERSION=$(echo "$ALL_VERSIONS" | tail -1)
echo "Found $TOTAL_VERSIONS versions (filtered to 13.x for net10.0 compat)"
echo "  Range: $LAST_VERSION ... $FIRST_VERSION"

# --- Create a worktree and set package versions ---
prepare_version() {
    local version="$1"
    local worktree_dir="$WORKTREE_BASE/$version"
    local evidence_version_dir="$EVIDENCE_DIR/$version"

    # Skip if already tested
    if [[ -f "$evidence_version_dir/result.txt" ]]; then
        echo "  [SKIP] $version already tested"
        return 0
    fi

    echo "  [PREPARE] $version"
    mkdir -p "$evidence_version_dir/dcp-logs"

    local branch_name="bisect/$version"

    # Create branch from HEAD
    echo "    Creating branch $branch_name..."
    git -C "$REPO_ROOT" branch "$branch_name" HEAD 2>/dev/null || true

    # Create worktree
    if [[ ! -d "$worktree_dir" ]]; then
        echo "    Creating worktree at $worktree_dir..."
        git -C "$REPO_ROOT" worktree add "$worktree_dir" "$branch_name" --quiet 2>/dev/null || true
    fi

    # Update ALL Aspire package versions — SDK and all Aspire.* packages must match
    echo "    Setting all Aspire packages to $version..."

    # Update Aspire.AppHost.Sdk version (sed — dotnet CLI can't modify Sdk elements)
    find "$worktree_dir" -name '*.csproj' -exec \
        sed -i "s|<Sdk Name=\"Aspire.AppHost.Sdk\" Version=\"[^\"]*\"|<Sdk Name=\"Aspire.AppHost.Sdk\" Version=\"$version\"|" {} +

    # Update all Aspire.Hosting.* and Aspire.* package references
    find "$worktree_dir" -name '*.csproj' -exec \
        sed -i -E "s|(Include=\"Aspire\.[^\"]+\") Version=\"[^\"]*\"|\1 Version=\"$version\"|g" {} +

    echo "    Versions set in csproj files:"
    grep -rh "Aspire" "$worktree_dir" --include='*.csproj' | grep -E '(Sdk|PackageReference)' | sed 's/^/      /'

    # Restore
    echo "    Restoring packages..."
    dotnet restore "$worktree_dir/aspire.slnx" 2>&1 | tail -5 || true
    echo "    [READY] $version"
}

# --- Test a single version ---
# Runs `dotnet test` in the worktree.
# Returns 0 for GOOD (test passes), 1 for BAD (test fails).
run_test() {
    local version="$1"
    local worktree_dir="$WORKTREE_BASE/$version"
    local evidence_version_dir="$EVIDENCE_DIR/$version"

    # Use cached result
    if [[ -f "$evidence_version_dir/result.txt" ]]; then
        local cached
        cached=$(cat "$evidence_version_dir/result.txt")
        echo "[CACHED] $version = $cached"
        [[ "$cached" == "GOOD" ]] && return 0 || return 1
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[TEST] $version"
    echo "  Worktree: $worktree_dir"
    echo "  Evidence: $evidence_version_dir"
    echo "  Timeout:  ${TEST_TIMEOUT}s"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    mkdir -p "$evidence_version_dir/dcp-logs"

    local start_time
    start_time=$(date +%s)

    local result
    BISECT_TIMEOUT="$TEST_TIMEOUT" \
       DCP_DIAGNOSTICS_LOG_LEVEL=debug \
       DCP_DIAGNOSTICS_LOG_FOLDER="$evidence_version_dir/dcp-logs" \
       DCP_PRESERVE_EXECUTABLE_LOGS=true \
       ASPIRE_ALLOW_UNSECURED_TRANSPORT=true \
       ASPNETCORE_URLS="http://127.0.0.1:19777" \
       ASPIRE_DASHBOARD_OTLP_HTTP_ENDPOINT_URL="http://127.0.0.1:19778" \
       DOTNET_RESOURCE_SERVICE_ENDPOINT_URL="http://127.0.0.1:19779" \
       dotnet test "$worktree_dir/BisectTest/BisectTest.csproj" \
           --no-restore \
           --verbosity normal \
           --logger "console;verbosity=detailed" \
           > "$evidence_version_dir/stdout.log" 2>&1
    local test_exit=$?

    # Show last 30 lines of test output
    echo "  --- test output (last 30 lines) ---"
    tail -30 "$evidence_version_dir/stdout.log" | sed 's/^/  /'
    echo "  --- end test output (exit=$test_exit) ---"

    if [[ $test_exit -eq 0 ]]; then
        result="GOOD"
    else
        result="BAD"
    fi

    local end_time elapsed
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))

    echo "$result" > "$evidence_version_dir/result.txt"
    echo ""
    echo "[${result}] $version (${elapsed}s)"

    [[ "$result" == "GOOD" ]] && return 0 || return 1
}

# --- Clean up a worktree ---
cleanup_worktree() {
    local version="$1"
    local worktree_dir="$WORKTREE_BASE/$version"
    local branch_name="bisect/$version"

    if [[ -d "$worktree_dir" ]]; then
        echo "  [CLEANUP] Removing worktree $version..."
        git -C "$REPO_ROOT" worktree remove "$worktree_dir" --force 2>/dev/null || true
    fi
    git -C "$REPO_ROOT" branch -D "$branch_name" 2>/dev/null || true
}

# --- Auto-detect bounds if not provided ---
auto_detect_bounds() {
    echo "Auto-detecting bounds..."

    local -a va
    mapfile -t va <<< "$ALL_VERSIONS"
    local total=${#va[@]}

    # Step 1: Establish GOOD first — try the latest stable (non-preview) version
    local stable_version
    stable_version=$(echo "$ALL_VERSIONS" | grep -v 'preview' | tail -1)

    if [[ -z "$GOOD_VERSION" ]]; then
        if [[ -n "$stable_version" ]]; then
            echo "Testing latest stable: $stable_version"
            prepare_version "$stable_version"
            if run_test "$stable_version"; then
                cleanup_worktree "$stable_version"
                GOOD_VERSION="$stable_version"
                echo "Confirmed GOOD: $GOOD_VERSION"
            else
                cleanup_worktree "$stable_version"
                echo "WARNING: Latest stable ($stable_version) is BAD — falling back to exponential search"
            fi
        else
            echo "No stable versions in 13.x range — falling back to exponential search"
        fi
    fi

    # If still no GOOD, jump backwards by doubling intervals
    if [[ -z "$GOOD_VERSION" ]]; then
        local step=4
        while [[ $step -lt $total ]]; do
            local candidate="${va[$step]}"
            echo "Testing $candidate (index $step)..."
            prepare_version "$candidate"
            if run_test "$candidate"; then
                cleanup_worktree "$candidate"
                GOOD_VERSION="$candidate"
                echo "Found GOOD: $GOOD_VERSION"
                break
            fi
            cleanup_worktree "$candidate"
            step=$((step * 2))
        done
    fi

    # Last resort: try the very oldest
    if [[ -z "$GOOD_VERSION" ]]; then
        local oldest="${va[$((total - 1))]}"
        echo "Testing oldest: $oldest"
        prepare_version "$oldest"
        if run_test "$oldest"; then
            cleanup_worktree "$oldest"
            GOOD_VERSION="$oldest"
            echo "Found GOOD: $GOOD_VERSION"
        else
            cleanup_worktree "$oldest"
            echo "ERROR: Could not find any good version!"
            exit 1
        fi
    fi

    # Step 2: Establish BAD — test the latest version
    if [[ -z "$BAD_VERSION" ]]; then
        local latest="${va[0]}"
        echo "Testing latest: $latest"
        prepare_version "$latest"
        if run_test "$latest"; then
            echo "Latest version ($latest) is GOOD -- no regression found!"
            cleanup_worktree "$latest"
            exit 0
        fi
        cleanup_worktree "$latest"
        BAD_VERSION="$latest"
        echo "Confirmed BAD: $BAD_VERSION"
    fi
}

if [[ -z "$GOOD_VERSION" ]] || [[ -z "$BAD_VERSION" ]]; then
    auto_detect_bounds
fi

echo ""
echo "Bisecting between:"
echo "  GOOD: $GOOD_VERSION"
echo "  BAD:  $BAD_VERSION"
echo ""

# --- Get versions in range (oldest first) ---
RANGE_VERSIONS=$(echo "$ALL_VERSIONS" \
    | sed -n "/${BAD_VERSION}/,/${GOOD_VERSION}/p" \
    | tac)

RANGE_COUNT=$(echo "$RANGE_VERSIONS" | wc -l)
echo "Versions in range: $RANGE_COUNT"

if [[ "$RANGE_COUNT" -le 2 ]]; then
    {
        echo "GOOD: $GOOD_VERSION"
        echo "BAD:  $BAD_VERSION"
    } > "$EVIDENCE_DIR/summary.txt"
    echo ""
    echo "=== BISECT COMPLETE ==="
    cat "$EVIDENCE_DIR/summary.txt"
fi

# --- Smart adaptive bisect ---
bisect_round() {
    local -a versions
    mapfile -t versions <<< "$1"
    local count=${#versions[@]}
    local round=$2

    echo ""
    echo "--- Round $round: $count versions in range ---"

    if [[ $count -le 2 ]]; then
        {
            echo "GOOD: ${versions[0]}"
            echo "BAD:  ${versions[$((count - 1))]}"
        } > "$EVIDENCE_DIR/summary.txt"
        echo ""
        echo "=== BISECT COMPLETE ==="
        cat "$EVIDENCE_DIR/summary.txt"
        return
    fi

    # Pick evenly spaced samples (always include endpoints)
    local -a samples=()
    local step=$(( count / (SAMPLES_PER_ROUND - 1) ))
    [[ $step -lt 1 ]] && step=1

    for (( i=0; i<count; i+=step )); do
        samples+=("${versions[$i]}")
    done
    if [[ "${samples[-1]}" != "${versions[$((count - 1))]}" ]]; then
        samples+=("${versions[$((count - 1))]}")
    fi

    echo "Sampling ${#samples[@]} versions (step=$step):"

    # Prepare worktrees (sequential)
    local -a to_test=()
    for v in "${samples[@]}"; do
        if [[ -f "$EVIDENCE_DIR/$v/result.txt" ]]; then
            echo "  (cached) $v = $(cat "$EVIDENCE_DIR/$v/result.txt")"
        else
            echo "  (prepare) $v"
            prepare_version "$v"
            to_test+=("$v")
        fi
    done

    # Run tests sequentially (Aspire DCP port conflicts with parallel runs)
    if [[ ${#to_test[@]} -gt 0 ]]; then
        echo ""
        echo "Running ${#to_test[@]} tests..."
        for v in "${to_test[@]}"; do
            run_test "$v" || true
            cleanup_worktree "$v"
        done
    fi

    # Find transition point
    local last_good="" first_bad=""
    echo ""
    echo "Round $round results (oldest to newest):"
    for v in "${samples[@]}"; do
        local r="UNKNOWN"
        [[ -f "$EVIDENCE_DIR/$v/result.txt" ]] && r=$(cat "$EVIDENCE_DIR/$v/result.txt")

        if [[ "$r" == "GOOD" ]]; then
            last_good="$v"
            echo "  GOOD  $v"
        elif [[ "$r" == "BAD" ]]; then
            [[ -z "$first_bad" ]] && first_bad="$v"
            echo "  BAD   $v"
        else
            echo "  ???   $v"
        fi
    done

    if [[ -z "$last_good" ]] || [[ -z "$first_bad" ]]; then
        echo "ERROR: Could not find transition in round $round."
        return 1
    fi

    echo ""
    echo "Transition zone: $last_good (good) ... $first_bad (bad)"

    local narrow
    narrow=$(printf '%s\n' "${versions[@]}" \
        | sed -n "/${last_good}/,/${first_bad}/p")

    bisect_round "$narrow" $((round + 1))
}

bisect_round "$RANGE_VERSIONS" 1

# --- Clean up all remaining worktrees ---
echo ""
echo "Cleaning up worktrees..."
for wt in "$WORKTREE_BASE"/*/; do
    [[ -d "$wt" ]] || continue
    v=$(basename "$wt")
    cleanup_worktree "$v"
done
rmdir "$WORKTREE_BASE" 2>/dev/null || true

# --- Commit evidence ---
echo ""
echo "Committing evidence..."
cd "$REPO_ROOT"
git add evidence/
git commit -m "$(cat <<EOF
evidence: bisect results $TIMESTAMP

$(cat "$EVIDENCE_DIR/summary.txt" 2>/dev/null || echo "Bisect completed")

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

echo ""
echo "=== Evidence committed ==="
if [[ -f "$EVIDENCE_DIR/summary.txt" ]]; then
    cat "$EVIDENCE_DIR/summary.txt"
fi
echo ""
echo "Logs: $EVIDENCE_DIR/<version>/{stdout.log,dcp-logs/}"
