# code-guards

Protective hooks that prevent Claude from accidentally modifying sensitive files. Provides guard rails for any codebase.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install code-guards@wonderforgelabs-plugins
```

## What It Guards

### PreToolUse Blocks (prevents editing)

| Guard | Patterns | Purpose |
|-------|----------|---------|
| Environment files | `*.env`, `*.env.*`, `*secrets.json`, `*secrets.yaml`, `*secrets.yml`, `*secrets.env`, `*.secret` | Prevent accidental secret exposure |
| Generated code | `*/Generated/*`, `*/obj/*`, `*/bin/*`, `*/dist/*`, `*/build/*` | Protect build outputs |
| Lock files | `yarn.lock`, `*/yarn.lock`, `package-lock.json`, `*/package-lock.json`, `packages.lock.json`, `*/packages.lock.json`, `pnpm-lock.yaml`, `*/pnpm-lock.yaml`, `Cargo.lock`, `*/Cargo.lock`, `go.sum`, `*/go.sum`, `poetry.lock`, `*/poetry.lock`, `Gemfile.lock`, `*/Gemfile.lock`, `composer.lock`, `*/composer.lock` | Prevent dependency corruption |

### PostToolUse Checks (runs after editing)

| Check | Tool | Purpose |
|-------|------|---------|
| Shell linting | shellcheck | Catches shell script issues after editing |

## Configuration

On first hook run, the plugin copies its default config to your project at:

```
.claude/code-guards/config.yaml
```

You can edit this file to customize guard behavior:

- **Add or remove patterns** per guard to match your project structure
- **Disable a guard entirely** by setting `enabled: false`
- **Adjust shellcheck severity** via `shellcheck_severity` (error, warning, info, style)

The config is per-project, so each repo can have its own rules.

## Files

| Path | Purpose |
|------|---------|
| `defaults/config.yaml` | Default guard patterns and settings, copied to project on first run |
| `hooks/hooks.json` | Hook definitions that wire guards to PreToolUse/PostToolUse events |
| `hooks/scripts/guard-check.sh` | Generic guard script that reads patterns from config and blocks matching files |
| `hooks/scripts/shellcheck-guard.sh` | Runs shellcheck on `.sh` files with config-driven severity |

## Requirements

- `jq` (required, used to parse hook stdin JSON)
- `yq` (required, or Docker with `mikefarah/yq` image as fallback)
- `shellcheck` (optional, skips gracefully if not installed)
