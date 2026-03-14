# Known Bisect Results

Previously bisected Aspire regressions and their findings.

## Keycloak Container Never Created (2026-03-07)

**Symptom**: `AddKeycloak()` creates DCP Services but never creates the Docker container. Resource stuck at "Starting" forever.

**Bisect Result**:
- GOOD: `13.3.0-preview.1.26124.2`
- BAD: `13.3.0-preview.1.26124.16`

**Conditions**: Only reproduces when dashboard is enabled (`DisableDashboard = false`). `DistributedApplicationTestingBuilder` disables dashboard by default, which bypasses the broken code path in `DashboardEventHandlers.OnBeforeStartAsync`.

**DCP Evidence**: `ContainerReconciler` never appears in run-controllers logs for keycloak. `ServiceReconciler` entries exist (DCP Services created), but no Container object was ever submitted.

**Root Cause**: Under investigation -- regression in dashboard event handler pipeline that prevents container spec submission to DCP.
