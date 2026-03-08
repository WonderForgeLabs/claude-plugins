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
| Jest auto-run | Runs related test file if it exists | Source file edit (skips test files) |

### Hookify Rules (warnings)

| Rule | What | When |
|------|------|------|
| Console log warning | Warns about `console.log()` in production code | Non-test TS/JS files |
| Any type warning | Warns about TypeScript `any` type usage | Any `.ts`/`.tsx` file |

## Requirements

- Node.js with `npx` available
- ESLint configured in the project
- TypeScript configured (`tsconfig.json`)
- Jest configured (optional, skips if no test file found)
