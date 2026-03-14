---
name: debug-dcp
description: "This skill should be used when the user reports \"container stuck in Starting\", \"resource never starts\", \"container not created\", \"DCP logs\", \"port allocation error\", or when Aspire resources fail to start with no errors in standard Aspire logs. Provides DCP (Developer Control Plane) debug logging, log analysis, and known failure patterns."
---

# Debug DCP (Developer Control Plane)

DCP is the layer below Aspire that orchestrates Docker containers. When Aspire resources are stuck in "Starting" with no errors, the problem is usually between Aspire and DCP -- Aspire failed to submit a Container object to DCP's internal API server.

## Step 1: Enable DCP Debug Logging

Set these environment variables before starting the AppHost:

```bash
DCP_DIAGNOSTICS_LOG_LEVEL=debug \
DCP_DIAGNOSTICS_LOG_FOLDER=/tmp/dcp-logs \
DCP_PRESERVE_EXECUTABLE_LOGS=true \
dotnet run --project <your-apphost-project>
```

Or in a test:

```bash
DCP_DIAGNOSTICS_LOG_LEVEL=debug \
DCP_DIAGNOSTICS_LOG_FOLDER=/tmp/dcp-logs \
DCP_PRESERVE_EXECUTABLE_LOGS=true \
dotnet test --filter "ClassName"
```

## Step 2: Identify DCP Log Files

After running, check `DCP_DIAGNOSTICS_LOG_FOLDER` for these files:

| File pattern | Contains |
|---|---|
| `*run-controllers*.log` | ContainerReconciler, ServiceReconciler -- container lifecycle |
| `*start-apiserver*.log` | API server CRUD -- which objects were submitted |
| `*monitor-process*.log` | Process monitoring (less useful for container issues) |
| `*info*.log` | DCP startup metadata |

## Step 3: Diagnose the Problem

### Check if the Container object was submitted to DCP

```bash
# If this returns 0, DCP never received the container -- the bug is in Aspire
grep -c "ContainerReconciler" /tmp/dcp-logs/*run-controllers*.log

# Compare with services -- these are always created
grep "ServiceReconciler" /tmp/dcp-logs/*run-controllers*.log | grep "<resource-name>"
```

### Check if container was scheduled to start

```bash
# Working containers show "Scheduling container start"
grep "Scheduling container start" /tmp/dcp-logs/*run-controllers*.log
```

### Check API server for submitted objects

```bash
# Shows which Container objects were ADDED (submitted by Aspire)
grep '"msg":"ADDED"' /tmp/dcp-logs/*start-apiserver*.log | grep containers

# Shows cleanup -- if "No resource instances found" for containers, none were ever created
grep "No resource instances found" /tmp/dcp-logs/*start-apiserver*.log
```

### Check for port allocation errors

```bash
# Port 0 causes ArgumentOutOfRangeException in AllocatedEndpoint
grep -i "port.*0\|ArgumentOutOfRange\|AllocatedEndpoint" /tmp/dcp-logs/*.log
```

## Diagnosis Decision Tree

```
Resource stuck in "Starting"?
+-- grep ContainerReconciler -> 0 hits?
|   +-- Container never submitted to DCP
|       +-- Bug is in Aspire hosting extension (AddXxx method)
|       +-- Check: SubscribeHttpsEndpointsUpdate, WithHttpsCertificateConfiguration
|       +-- Check: BeforeStartEvent subscriptions that may block
|
+-- ContainerReconciler exists but no "Scheduling container start"?
|   +-- Container submitted but DCP rejected it
|       +-- Check DCP controller logs for errors near the resource name
|
+-- "Scheduling container start" exists but docker ps shows nothing?
|   +-- Docker daemon issue
|       +-- Check: docker ps -a, docker info, disk space
|
+-- Container starts but resource stays "Starting"?
    +-- Health check issue
        +-- See aspire skill: Health Check Gotchas
```

## Additional Resources

For known DCP issues, workarounds, and debugging strategies, consult the official Aspire documentation using the `search_docs` MCP tool with keywords like "DCP", "container lifecycle", or "resource startup".
