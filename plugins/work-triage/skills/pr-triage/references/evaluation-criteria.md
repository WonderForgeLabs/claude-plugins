# PR Evaluation Criteria

## Staleness Signals

| Signal | Severity | Detection |
|--------|----------|-----------|
| Age > 30 days with no updates | High | `createdAt` / `updatedAt` delta |
| Behind default branch by 50+ commits | High | `gh api repos/{REPO}/compare/{DEFAULT_BRANCH}...{BRANCH} --jq .behind_by` |
| Merge conflicts present | Medium | `mergeable: CONFLICTING` from `gh pr view` |
| No CI checks passing | Medium | `gh pr checks {NUMBER}` shows failures |
| Author has not responded in 14+ days | Medium | Last comment timestamp from author |
| Branch deleted upstream | High | `git ls-remote origin {BRANCH}` returns empty |

## Superseded Signals

| Signal | Detection |
|--------|-----------|
| Same files modified on main after PR creation | `git log $DEFAULT_BRANCH --since={CREATED} -- {FILES}` has hits |
| Same function/class names exist with different implementation | Grep default branch for identifiers from the PR diff |
| Feature flag referenced in PR was removed from main | Grep for flag name, absent on main |
| PR description references a design that changed | Manual assessment — compare PR goals to current code |
| Another PR merged that addresses the same issue | `git log $DEFAULT_BRANCH --grep="#{ISSUE}"` or linked issue has merged PR |

## Bot PR Patterns

### copilot-swe-agent
- Often abandoned when a human fix lands first
- Check: was the linked issue fixed by a different (merged) PR?
- Check: does the fix approach conflict with how the code evolved?
- If issue is still open and no human fix exists: may still be viable

### dependabot[bot] / renovate[bot]
- Check if the dependency version in the PR is still the latest
- Check if the same dependency was updated in a different commit on main
- Security PRs (label `security`) have higher urgency — prefer rebasing over closing

## Recommendation Decision Matrix

```
Has work landed on the default branch for this PR's goals?
├── Yes → Close (completed)
└── No
    Has the surrounding code changed architecturally?
    ├── Yes, fundamentally → Close (superseded)
    ├── Yes, but PR concept is still valid → Rework
    └── No
        Are there merge conflicts?
        ├── Major conflicts (5+ files) → Rework
        ├── Minor conflicts (1-4 files) → Rebase & merge
        └── No conflicts
            Was PR updated in last 7 days?
            ├── Yes → Keep
            └── No
                Is author responsive?
                ├── Yes → Rebase & merge (ping author)
                └── No → Add "stale" label, comment
```

## Conflict Severity

- **Minor**: 1-4 files, mostly import/whitespace changes, no logic conflicts
- **Major**: 5+ files, or logic conflicts in core files, or conflicts in generated code that requires regeneration
- **Architectural**: conflicts indicate the PR's approach is no longer compatible (e.g., entire module was restructured)
