# Issue Evaluation Criteria

## Completion Signals

| Signal | Confidence | Detection |
|--------|------------|-----------|
| Commit on default branch references issue number | High | `git log $DEFAULT_BRANCH --grep="#{NUMBER}"` |
| Linked PR was merged | High | `gh api repos/{REPO}/issues/{NUMBER}/timeline` cross-references with merged PRs |
| Code described in issue exists on main | Medium | Grep for feature/function names from issue body |
| Issue author commented "done" or "fixed" | Medium | Parse issue comments for acknowledgement |
| All checklist items in issue body are checked | Medium | Parse `- [x]` vs `- [ ]` in body |

## Staleness Signals

| Signal | Severity | Detection |
|--------|----------|-----------|
| Age > 90 days with no activity | High | `createdAt` / `updatedAt` delta |
| No linked PRs, no commits referencing it | High | Timeline API + git log search |
| Assignee has no recent activity | Medium | `gh api users/{ASSIGNEE}/events --jq length` |
| References deprecated APIs or removed features | High | Grep codebase for identifiers from issue |
| Project board status stuck at "Backlog" for 60+ days | Medium | `projectItems[].status` |

## Blocked / Unblocked Detection

Issues may express blocking relationships in several ways:

1. **Label-based**: `blocked` label present
2. **Body text**: "blocked by #X", "depends on #X", "waiting for #X"
3. **Project field**: "Blocked" status on project board
4. **Sub-issue relationship**: Parent issue with incomplete children

To check if a blocker is resolved:
```bash
# Extract referenced issue numbers from body
BLOCKERS=$(gh issue view {NUMBER} --json body -q .body | grep -oE '(blocked by|depends on|waiting for) #[0-9]+' | grep -oE '[0-9]+$')

# Check each blocker's state
for B in $BLOCKERS; do
  gh issue view $B --json state -q .state
done
```

## Epic / Sub-Issue Patterns

Large issues that should be split exhibit these patterns:
- Multiple distinct features described in one issue
- Checklist with 5+ items spanning different subsystems
- Comments requesting scope reduction
- Multiple failed PRs attempting partial implementation

## Recommendation Decision Matrix

```
Is the described work done on the default branch?
├── Fully done → Close (completed)
├── Partially done
│   └── Remaining work still relevant?
│       ├── Yes → Update (describe what remains)
│       └── No → Close (irrelevant)
└── Not done
    Is the issue still relevant?
    ├── No (architecture changed, feature removed, etc.) → Close (irrelevant)
    └── Yes
        Is it blocked?
        ├── Yes
        │   └── Is the blocker resolved?
        │       ├── Yes → Unblock (remove blocked label, update status)
        │       └── No → Keep (still blocked)
        └── No
            Is it too large?
            ├── Yes → Split (suggest sub-issues)
            └── No
                Has it been idle > 90 days?
                ├── Yes → Add "stale" label, comment asking if still relevant
                └── No → Keep
```

## Evidence Quality

When recommending closure, evidence should be specific:

- **Good**: "Closed by PR #55 (merged 2024-01-15) which added the widget API at `src/api/widgets.ts:42`"
- **Bad**: "Looks like this was probably done"

When uncertain, recommend **Keep** with a comment asking the author/assignee for status rather than closing prematurely.
