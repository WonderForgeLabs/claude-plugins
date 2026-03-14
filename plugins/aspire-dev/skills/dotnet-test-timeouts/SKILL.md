---
name: dotnet-test-timeouts
description: "Diagnose dotnet test timeouts, Aspire fixture TimeoutException, CI job killed at 5-7 min, WaitForResourceAsync hanging, all Aspire tests failing identically, port collision, resource startup crash."
---

# Debugging .NET Test Timeouts

## Overview

When all Aspire-collection tests fail with the same `TimeoutException`, the Aspire fixture couldn't start. **The root cause is always in the resource logs, never in the test code.** Download CI artifacts and read the aspire-logs before touching anything.

## Diagnosis Workflow

### Step 1: Download CI Artifacts

Check your CI workflow configuration for artifact names. Artifacts typically include test results and aspire resource logs. For example:

```bash
# Download test result artifacts from CI
gh run download <run-id> --repo <owner>/<repo> -n <artifact-name>
```

### Step 2: Read the Aspire Resource Logs

The logs live at `TestResults/aspire-logs/<resource-name>.<hostname>.log`. Read the logs for the main application resource first:

```bash
# Check the app service log -- this is where startup failures surface
cat TestResults/aspire-logs/<app-service>.*.log | grep -i "fail\|error\|exception\|unhandled" -A5

# Check all resource logs for errors
for f in TestResults/aspire-logs/*.log; do
  echo "=== $(basename $f) ==="
  grep -i "fail\|error\|exception" "$f" | head -5
done
```

### Step 3: Check Docker Container Logs

CI may also dump raw docker container logs:

```bash
ls *.log  # Container logs: <container-name>.<hostname>.log
```

### Step 4: Check TRX Files for Failure Pattern

```bash
# Mass TimeoutException = fixture startup failed (look at resource logs)
grep -l "TimeoutException" TestResults/*.trx

# Individual test failures = look at specific test errors
grep "outcome=\"Failed\"" TestResults/*.trx | head -20
```

## Known Root Causes (from real CI failures)

### Port Collision: "Address already in use"

**Symptom in resource log:**
```
System.IO.IOException: Failed to bind to address http://127.0.0.1:44703: address already in use.
 ---> System.Net.Sockets.SocketException (98): Address already in use
```

**What happens:** Aspire assigns a dynamic port. Another process (or a previous test run's zombie) already holds that port. Kestrel fails to bind, the generic host's `BackgroundServiceExceptionBehavior = StopHost` kills the entire host, background services get `TaskCanceledException`, and the app process dies within seconds. The resource never reaches `Running`, so `WaitForResourceAsync` blocks until the timeout.

**Fix:** Transient CI issue. Retry the workflow. If persistent, check for zombie processes.

### Slow Infrastructure Startup

**Symptom:** Infrastructure services (databases, identity providers, message brokers) take longer than expected to start. For example, a Keycloak realm import normally takes ~55 seconds but can spike to 90+ seconds under CI load.

**What happens:** The application waits for dependent services via `WaitFor()`. If infrastructure startup exceeds expectations, the cumulative wait pushes the total fixture startup past the timeout.

**Fix:** Monitor infrastructure startup times in resource logs. Consider increasing the fixture timeout only if infrastructure startup is genuinely slow under your CI environment.

### Resource Health Check Blocking

**Symptom:** App waiting for a resource to become healthy, but that resource IS running.

**Key pattern:** `WithHttpHealthCheck` uses a default HttpClient that does NOT bypass TLS verification. If a container uses self-signed certs, the health check silently fails, and `WaitFor()` blocks all dependents forever.

**Fix:** Use file-based health checks for resources with self-signed TLS, or configure the health check HttpClient to bypass certificate validation.

### Stream/Queue "Not Found" Errors

**Symptom in resource log:**
```
stream not found
```
or similar message-broker initialization errors.

**What happens:** A consumer starts before the stream or queue is created. Normally handled by retry logic. If the app crashes before initialization completes, this appears in logs but is NOT the root cause -- look for what actually crashed the process.

## Timeout Chain Reference

| Layer | Timeout | Effect When Hit |
|-------|---------|-----------------|
| CI job | Varies (5-15 min/shard) | Job killed, artifacts may not upload |
| Aspire fixture startup | 5 min (typical default) | `TimeoutException`, every Aspire test fails identically |
| HTTP resilience | 60 sec/request | Request fails with retry |
| Per-test | 10-30 sec (if set) | Individual test fails |

## Anti-Patterns

- **Increasing the fixture startup timeout** -- masks the real problem; the resource logs will tell you what actually failed
- **Retrying CI without reading logs** -- transient port collisions fix themselves, but real failures won't
- **Looking at test code when ALL Aspire tests fail identically** -- uniform failure = infrastructure problem, not a test bug
- **Blaming the test framework** -- xUnit, NUnit, MSTest are never the cause of Aspire fixture timeouts
