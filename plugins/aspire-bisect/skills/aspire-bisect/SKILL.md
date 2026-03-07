---
name: aspire-bisect
description: "This skill should be used when the user asks to \"bisect aspire versions\", \"find aspire regression\", \"which aspire version broke\", \"test aspire dailies\", \"bisect NuGet packages\", or when an Aspire bug needs to be pinpointed to a specific preview build. Provides a version bisection workflow using git worktrees and adaptive sampling."
---

# Aspire Version Bisect

Pinpoint which Aspire NuGet daily build introduced a regression by bisecting across package versions. Uses git worktrees for isolation and adaptive sampling (3 samples per round) to minimize test runs.

## Prerequisites

- A **standalone repro repo** (not the main project) -- a minimal git repo with:
  - `AppHost/` project using `AddXxx()` for the broken resource
  - `BisectTest/` xUnit test project that exercises the bug
  - `aspire.slnx` solution file
  - `bisect.sh` script (bundled with this skill)
- All files must be **committed** (worktrees clone from HEAD)
- Docker running (for Aspire DCP containers)

## Workflow

### 1. Create the Repro Repo

Create a minimal standalone repo outside the main project:

```bash
mkdir /tmp/aspire-bisect-repro && cd /tmp/aspire-bisect-repro
git init
```

Create `AppHost/AppHost.csproj`:
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <Sdk Name="Aspire.AppHost.Sdk" Version="13.3.0-preview.1.26156.8" />
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <IsAspireHost>true</IsAspireHost>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.Keycloak" Version="13.3.0-preview.1.26156.8" />
    <!-- Add the broken hosting package here -->
  </ItemGroup>
</Project>
```

Create `AppHost/AppHost.cs` with the minimal reproduction:
```csharp
var builder = DistributedApplication.CreateBuilder(args);
builder.AddKeycloak("keycloak"); // Replace with failing resource
builder.Build().Run();
```

Create `AppHost/Properties/launchSettings.json` with a `test` profile using fixed ports:
```json
{
  "profiles": {
    "test": {
      "commandName": "Project",
      "applicationUrl": "http://127.0.0.1:19777",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "ASPIRE_ALLOW_UNSECURED_TRANSPORT": "true",
        "ASPIRE_DASHBOARD_OTLP_HTTP_ENDPOINT_URL": "http://127.0.0.1:19778",
        "DOTNET_RESOURCE_SERVICE_ENDPOINT_URL": "http://127.0.0.1:19779"
      }
    }
  }
}
```

### 2. Create the Test Oracle

The test must return pass/fail as the bisect oracle. Key patterns:

- **Enable dashboard** via `DisableDashboard = false` if the bug requires it
- Use `--launch-profile test` args for fixed dashboard ports
- **Fire-and-forget** `StartAsync` -- don't await it, since a broken version blocks forever
- Watch `ResourceNotificationService` for the resource reaching "Running"
- Use `BISECT_TIMEOUT` env var for configurable timeout

Consult `references/test-template.md` for a complete test template.

### 3. Run the Bisect

Copy `scripts/bisect.sh` to the repro repo root, then:

```bash
# Auto-detect bounds (tests latest stable as GOOD, latest preview as BAD)
./bisect.sh --timeout 30

# Or specify known bounds
./bisect.sh --good 13.3.0-preview.1.26124.2 --bad 13.3.0-preview.1.26156.8
```

The script:
1. Fetches all versions from the Aspire NuGet feed
2. Filters to 13.x (net10.0 compatible)
3. Establishes GOOD (latest stable first) and BAD (latest preview)
4. Bisects with 3 samples per round using git worktrees
5. Updates all `Aspire.*` package references via sed
6. Collects DCP logs and test output as evidence
7. Commits results to `evidence/bisect-<timestamp>/`

### 4. Interpret Results

The summary file shows the transition:
```
GOOD: 13.3.0-preview.1.26124.2
BAD:  13.3.0-preview.1.26124.16
```

Version format: `major.minor.patch-preview.1.YMMDD.build` -- the date component helps correlate with Aspire repo commits.

## Key Constraints

- **Fixed ports required** -- `127.0.0.1:0` dynamic binding does NOT work with Aspire dashboard
- **Dashboard must be enabled** for bugs in the `DashboardEventHandlers.OnBeforeStartAsync` code path
- **All Aspire packages must match** -- SDK, hosting extensions, and testing packages use the same version
- **Tests run sequentially** -- DCP port conflicts prevent parallel test runs
- **`set -uo pipefail`** but NOT `-e` -- errexit causes silent failures with pipe chains

## Additional Resources

### Scripts
- **`scripts/bisect.sh`** -- The bisect script to copy into repro repos

### Reference Files
- **`references/test-template.md`** -- Complete BisectTest template with resource notification oracle
- **`references/known-results.md`** -- Previously bisected regressions and their root causes
