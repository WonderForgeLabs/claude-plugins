---
name: adr
description: Create Architecture Decision Record (ADR) or Domain Decision Record (DDR) following project conventions. Use when documenting significant technical or design decisions.
---

# ADR/DDR Generator

Create properly formatted Architecture Decision Records (ADRs) or Domain Decision Records (DDRs) following project conventions.

## Usage

```
/adr <type> <title>
```

- `type`: Either `adr` (technical/architecture) or `ddr` (domain/user experience)
- `title`: Brief description of the decision

## Examples

```
/adr adr Add WebSocket support for real-time updates
/adr ddr Artifact versioning strategy
```

## Workflow

1. **Determine next number**: Check existing files in `docs/ADR/` or `docs/DDR/`
2. **Gather context**: Ask clarifying questions about:
   - What problem are we solving?
   - What constraints exist?
   - What alternatives were considered?
3. **Generate the document** using the appropriate template

## ADR Template (docs/ADR/)

For technical/architecture decisions:

```markdown
# ADR-XXX: [Title]

## Status

Proposed

## Context

[Problem statement, constraints, assumptions]

## Decision

[What we decided, with architecture diagram if applicable]

## Alternatives Considered

### Alternative 1: [Name]
- **Pros:** ...
- **Cons:** ...
- **Decision:** Rejected - [reason]

## Implementation Guidelines

[Development and deployment considerations]

## Consequences

### Positive Consequences
- ...

### Negative Consequences
- ...

## Success Metrics

- ...

## Related ADRs

- ADR-XXX: [Related decision]

## References

- [Links to relevant documentation]

---
**Date:** YYYY-MM-DD
**Authors:** Development Team
**Reviewers:** Architecture Team
**Next Review:** YYYY-MM-DD (6 months)
```

## DDR Template (docs/DDR/)

For domain/user experience decisions:

```markdown
# DDR-XXX: [Title]

## Status

Proposed

## Context

[What design challenge or user experience problem are we addressing?]

## Decision

[What design approach, pattern, or user experience solution did we choose?]

## Rationale

[Why does this design choice better serve our users and align with the project's goals?]

## Consequences

**Positive:**
- ...

**Negative:**
- ...

**Implementation Impact:**
- ...

## Alternatives Considered

1. **[Option]**: Rejected - [reason]

## Notes

[Additional context, references, or future considerations]
```

## Key Principles

- ADRs: Focus on **technical architecture** (infrastructure, APIs, data flow)
- DDRs: Focus on **domain design** (user experience, entity modeling, workflows)
- Use mermaid diagrams for architecture visualizations
- Link related ADRs/DDRs for traceability
- Include concrete success metrics where possible
