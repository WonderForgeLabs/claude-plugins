---
name: bootstrap
description: Create a new GitHub Project V2 with opinionated defaults (fields, views, linked repo)
argument-hint: "[--name <name>] [--copy-from <project-number>]"
allowed-tools:
  - Bash
  - AskUserQuestion
---

Create a new GitHub Project V2 board with opinionated default fields, views, and linked repository.

## Step 1: Run the bootstrap script

Pass any user-provided flags through to the bootstrap script:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap-project.sh [flags]
```

Supported flags:
- `--name <name>` -- custom project name (default: `<repo> Board`)
- `--copy-from <project-number>` -- copy field and view structure from an existing project

If no flags were provided, run the script with defaults. The script will auto-detect the org from the git remote config.

## Step 2: Save the new project number

After the bootstrap script completes successfully, it prints the new project number. Run `/configure` to save that project number to the local config file so all other scripts can use it.

Alternatively, if the user wants to skip the interactive configure flow, write the config file directly using the detected org, repo, and new project number.

## Step 3: Configure the Auto-add workflow

Remind the user that the Auto-add workflow must be configured via the GitHub UI (the API does not support setting workflow filters). The bootstrap script prints a direct URL to the workflows page. The user needs to:

1. Click "Auto-add to project"
2. Click "Edit"
3. Select the linked repository
4. Set the filter (e.g. `is:issue,pr` to add all issues and PRs)
5. Save and enable the workflow
