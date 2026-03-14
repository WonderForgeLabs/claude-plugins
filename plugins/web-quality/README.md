# web-quality

TypeScript/JavaScript quality automation for Claude Code. Auto-lints, type-checks, and runs related tests after every edit.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install web-quality@wonderforgelabs-plugins
```

## What It Does

### PostToolUse Hooks (run after editing)

| Hook | What | When |
|------|------|------|
| ESLint auto-fix | Runs `eslint --fix` on changed files | Any `.ts`/`.tsx`/`.js`/`.jsx` edit |
| TypeScript check | Runs `tsc --noEmit` | Any `.ts`/`.tsx` edit |
| Jest auto-run | Runs related test file if it exists | Source or test file edit |

## Files

| Path | Purpose |
|------|---------|
| `hooks/hooks.json` | Hook definitions (PostToolUse triggers) |
| `hooks/scripts/eslint-fix.sh` | ESLint auto-fix script |
| `hooks/scripts/typecheck.sh` | TypeScript type-check script |
| `hooks/scripts/jest-related.sh` | Jest related-test runner |
| `defaults/config.yaml` | Default configuration (copied on first run) |
| `.claude-plugin/plugin.json` | Plugin metadata |

## Configuration

On the first hook run, the plugin copies its default config to your project:

```
.claude/web-quality/config.yaml
```

You can edit this file to customize behavior:

```yaml
eslint:
  enabled: true                                    # set to false to disable ESLint hook
  extensions: [".ts", ".tsx", ".js", ".jsx"]       # file extensions to lint
typescript:
  enabled: true                                    # set to false to disable type-checking
  extensions: [".ts", ".tsx"]                      # file extensions to type-check
jest:
  enabled: true                                    # set to false to disable test runner
  test_patterns: ["*.test.ts", "*.test.tsx", "*.spec.ts", "*.spec.tsx"]  # test file globs
```

- **Enable/disable** individual hooks by setting `enabled` to `true` or `false`.
- **Change file extensions** for ESLint or TypeScript to match your project.
- **Customize test patterns** for Jest to match your naming conventions.
- Config is parsed with `yq`. If `yq` is not installed, the plugin falls back to Docker (`mikefarah/yq` image). If neither is available, hooks exit gracefully with a warning.

## Requirements

- `jq` (for parsing hook stdin JSON)
- `yq` (for reading YAML config) or Docker with `mikefarah/yq` image
- Node.js with `npx` available
- ESLint configured in the project
- TypeScript configured (`tsconfig.json`)
- Jest configured (optional, skips if no test file found)
