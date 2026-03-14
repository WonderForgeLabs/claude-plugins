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
| Environment files | `*.env*`, `*secrets*`, `*.env.local` | Prevent accidental secret exposure |
| Generated code | `*/Generated/*`, `*/obj/*`, `*/bin/*`, `*/dist/*`, `*/build/*` | Protect build outputs |
| Lock files | `yarn.lock`, `package-lock.json`, `pnpm-lock.yaml`, `Cargo.lock`, `Gemfile.lock`, `composer.lock`, etc. | Prevent dependency corruption |

### PostToolUse Checks (runs after editing)

| Check | Tool | Purpose |
|-------|------|---------|
| Shell linting | shellcheck | Catches shell script issues after editing |

## Requirements

- `jq` (required, used to parse hook stdin JSON)
- `shellcheck` (optional, skips gracefully if not installed)
