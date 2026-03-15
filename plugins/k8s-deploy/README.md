# k8s-deploy

Kubernetes deployment workflow with Kustomize base+overlay, ArgoCD sync waves, and Vault secrets integration. Includes a YAML linting PostToolUse hook for deploy manifests.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install k8s-deploy@wonderforgelabs-plugins
```

## Usage

Once installed, invoke the skill in Claude Code:

```
/deploy-workflow
```

Or trigger it naturally by asking Claude to "add a new overlay", "modify the kustomize base", "update ArgoCD sync waves", or "add a Vault secret".

## What It Does

1. Provides a structured guide for Kustomize base+overlay deployment patterns
2. Includes a decision flow for where to make changes (base, overlay, Helm values, operators)
3. Documents ArgoCD sync wave ordering (operators -> postgres -> infrastructure -> application)
4. Covers Vault secret path and role naming conventions
5. Lints YAML files in `deploy/` automatically via PostToolUse hook

## YAML Linting Hook

The plugin includes a PostToolUse hook that runs `yamllint` on deploy YAML files whenever they are edited or written. The hook:

- Triggers on `Edit` and `Write` tool calls
- Only checks files matching `*/deploy/*.yaml`, `*/deploy/*.yml`, or `*kustomization*.yaml`
- Skips gracefully if `yamllint` is not installed
- Uses the `relaxed` profile to avoid false positives on Kubernetes manifests

## Requirements

- `kustomize` (for building and verifying overlays)
- `yamllint` (optional, for YAML linting hook)
- `jq` (required by YAML linting hook to parse tool input)
- A `deploy/` directory following the Kustomize base+overlay pattern

## Files

| File | Purpose |
|------|---------|
| `skills/deploy-workflow/SKILL.md` | Skill definition with full deploy workflow guide |
| `commands/deploy-workflow.md` | Slash command wiring for `/deploy-workflow` |
| `hooks/hooks.json` | PostToolUse YAML linting hook |
| `.claude-plugin/plugin.json` | Plugin metadata |
