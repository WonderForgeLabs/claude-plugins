# WonderForgeLabs Claude Plugins

A [Claude Code](https://claude.ai/claude-code) plugin marketplace by [WonderForgeLabs](https://github.com/WonderForgeLabs).

## Install

```bash
claude plugin marketplace add WonderForgeLabs/claude-plugins
```

Then install individual plugins:

```bash
claude plugin install <plugin-name>@wonderforgelabs-plugins
```

## Plugins

| Plugin | Description |
|--------|-------------|
| [adr](plugins/adr) | Architecture and Domain Decision Record generator with structured templates |
| [aspire-bisect](plugins/aspire-bisect) | Bisect .NET Aspire NuGet daily builds to pinpoint regressions |
| [aspire-dev](plugins/aspire-dev) | Comprehensive .NET Aspire development toolkit — orchestration, DCP debugging, test timeout diagnosis |
| [code-guards](plugins/code-guards) | Protective hooks that block editing environment files, generated code, and lock files |
| [dotnet-quality](plugins/dotnet-quality) | .NET development quality toolkit — TDD workflow, CI failure diagnosis, auto-formatting |
| [k8s-deploy](plugins/k8s-deploy) | Kubernetes deployment workflow with Kustomize, ArgoCD, and Vault patterns |
| [pr-feedback-sweep](plugins/pr-feedback-sweep) | Scan open PRs for unresolved review feedback and dispatch fix agents |
| [web-quality](plugins/web-quality) | TypeScript/JavaScript quality hooks — auto-lint, type-check, test runner, and code warnings |

## License

MIT
