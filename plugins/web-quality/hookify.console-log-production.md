---
name: warn-console-log-production
enabled: true
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: "(?!.*\\.(test|spec)\\.).*\\.(ts|tsx|js|jsx)$"
  - field: new_text
    operator: regex_match
    pattern: "console\\.(log|debug|info|warn|error)\\("
---

**Console statement in production code!**

Avoid `console.log()` in production source files.

**Alternatives:**
- Remove after debugging
- Use a proper logging utility if persistent logging is needed
- Move to a test file if it's for debugging
