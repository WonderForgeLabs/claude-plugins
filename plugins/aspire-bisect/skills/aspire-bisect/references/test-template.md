# BisectTest Template

Complete xUnit test that serves as the oracle for the bisect script. Adapt the resource name and assertion to match the specific bug being bisected.

## BisectTest.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsTestProject>true</IsTestProject>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.Testing" Version="13.3.0-preview.1.26156.8" />
    <PackageReference Include="xunit.v3" Version="3.1.0" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.1.0" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.0" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\AppHost\AppHost.csproj" />
  </ItemGroup>
</Project>
```

## KeycloakBisectTest.cs

```csharp
using System.Reflection;
using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Xunit;

namespace BisectTest;

public class KeycloakBisectTest(ITestOutputHelper output)
{
    [Fact]
    public async Task Keycloak_Container_Should_Be_Created()
    {
        var timeoutSeconds = int.TryParse(
            Environment.GetEnvironmentVariable("BISECT_TIMEOUT"), out var t) ? t : 60;

        var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeoutSeconds));

        // Log Aspire.Hosting.Testing version
        var hostingAsm = typeof(DistributedApplicationTestingBuilder).Assembly;
        var hostingVersion = hostingAsm.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? hostingAsm.GetName().Version?.ToString() ?? "unknown";
        output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] Aspire.Hosting.Testing: {hostingVersion}");

        output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] Creating AppHost (timeout: {timeoutSeconds}s)...");

        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.AppHost>(
                args: ["--launch-profile", "test"],
                configureBuilder: (appOptions, _) => appOptions.DisableDashboard = false,
                cancellationToken: cts.Token);

        appHost.Services.AddLogging(logging =>
        {
            logging.SetMinimumLevel(LogLevel.Trace);
            logging.AddFilter("Aspire.", LogLevel.Trace);
            logging.AddConsole();
        });

        output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] Building app...");
        await using var app = await appHost.BuildAsync(cts.Token);

        var notificationService = app.Services.GetRequiredService<ResourceNotificationService>();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Track target resource state via notifications
        var resourceRunning = false;
        const string targetResource = "keycloak"; // CHANGE THIS to your resource name
        _ = Task.Run(async () =>
        {
            try
            {
                await foreach (var evt in notificationService.WatchAsync(cts.Token))
                {
                    var state = evt.Snapshot.State?.Text ?? "unknown";
                    output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] Resource '{evt.Resource.Name}' -> {state}");

                    if (evt.Resource.Name == targetResource &&
                        string.Equals(state, "Running", StringComparison.OrdinalIgnoreCase))
                    {
                        resourceRunning = true;
                    }
                }
            }
            catch (OperationCanceledException) { }
        }, cts.Token);

        output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] Starting app...");
        output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] Resources: {string.Join(", ", model.Resources.Select(r => $"{r.Name} ({r.GetType().Name})"))}");

        // Fire-and-forget — StartAsync blocks until all resources are healthy,
        // which never happens when the bug prevents container creation.
        var startTask = app.StartAsync(cts.Token);
        _ = startTask.ContinueWith(t =>
        {
            if (t.IsFaulted)
                output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] StartAsync faulted: {t.Exception?.InnerException?.Message}");
            else if (t.IsCanceled)
                output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] StartAsync canceled");
            else
                output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] StartAsync completed");
        }, CancellationToken.None);

        // Wait for resource to reach Running, or timeout
        try
        {
            while (!resourceRunning && !cts.Token.IsCancellationRequested)
            {
                await Task.Delay(1000, cts.Token);
            }
        }
        catch (OperationCanceledException) { }

        output.WriteLine($"[{DateTime.UtcNow:HH:mm:ss}] Result: {(resourceRunning ? "GOOD - resource running" : "BAD - resource never started")}");
        Assert.True(resourceRunning, $"{targetResource} resource never reached Running state");
    }
}
```

## Key Patterns

### Fire-and-forget StartAsync
`app.StartAsync()` blocks until all resources are healthy. When the bug prevents a resource from starting, this blocks until timeout. Start it in background and poll resource state instead.

### Dashboard must be enabled
Set `DisableDashboard = false` in `configureBuilder` -- `DistributedApplicationTestingBuilder` disables the dashboard by default, which bypasses the `DashboardEventHandlers.OnBeforeStartAsync` code path where some container creation bugs live.

### Fixed ports required
Use `--launch-profile test` with fixed ports (e.g., 19777-19779) in `launchSettings.json`. Dynamic port binding (`127.0.0.1:0`) does NOT work with Aspire's dashboard.

### BISECT_TIMEOUT env var
The bisect script sets `BISECT_TIMEOUT` to control per-test timeout. The test reads it to configure `CancellationTokenSource`.
