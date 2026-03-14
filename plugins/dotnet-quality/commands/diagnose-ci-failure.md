---
name: diagnose-ci-failure
description: Diagnose CI pipeline failures
allowed-tools: ["Bash", "Read", "Glob", "Grep"]
argument-hint: "[run-id]"
---

Invoke the diagnose-ci-failure skill. Pass a run-id argument if you have one, otherwise the skill will find the latest failed run.
