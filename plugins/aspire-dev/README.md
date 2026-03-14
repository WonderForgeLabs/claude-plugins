# aspire-dev

Comprehensive .NET Aspire development toolkit -- orchestration, DCP debugging, and test timeout diagnosis. Pairs with the Aspire MCP server for real-time resource inspection and documentation lookups.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install aspire-dev@wonderforgelabs-plugins
```

## Skills

### aspire

Orchestrates Aspire applications using the Aspire CLI and MCP tools. Covers running, stopping, debugging, and managing distributed apps.

Trigger phrases: "aspire run", "start aspire app", "list aspire integrations", "debug aspire issues", "view aspire logs", "add aspire resource", "update aspire apphost".

### debug-dcp

DCP (Developer Control Plane) level diagnosis for resources stuck in "Starting" with no errors in standard Aspire logs. Provides environment variables, log file locations, grep commands, and a decision tree.

Trigger phrases: "container stuck in Starting", "resource never starts", "DCP logs", "port allocation error".

### dotnet-test-timeouts

Diagnoses .NET test timeouts caused by Aspire fixture startup failures. Covers CI artifact analysis, known root causes (port collisions, health check blocking, slow infrastructure), and anti-patterns.

Trigger phrases: "test timeout", "all tests failing", "TimeoutException", "WaitForResourceAsync hanging", "CI job killed".

## Requirements

- .NET SDK (version matching your Aspire project)
- Docker (for Aspire DCP containers)
- Aspire CLI (`dotnet tool install -g aspire`)
- Aspire MCP server (recommended, for real-time resource inspection)

## Files

| File | Purpose |
|------|---------|
| `skills/aspire/SKILL.md` | Aspire orchestration, debugging, and MCP tool guidance |
| `skills/debug-dcp/SKILL.md` | DCP-level diagnosis for stuck resources |
| `skills/dotnet-test-timeouts/SKILL.md` | Test timeout diagnosis with known root causes |
