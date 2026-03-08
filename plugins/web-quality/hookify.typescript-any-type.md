---
name: warn-typescript-any-type
enabled: true
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: ".*\\.tsx?$"
  - field: new_text
    operator: regex_match
    pattern: ":\\s*any\\b|<any>|as\\s+any\\b"
---

**TypeScript `any` type detected!**

This project uses TypeScript strict mode. The `any` type is not allowed.

**Alternatives:**
- Use `unknown` and narrow with type guards
- Define a proper interface or type
- Use generics for flexible typing
- Use `Record<string, unknown>` for object maps
