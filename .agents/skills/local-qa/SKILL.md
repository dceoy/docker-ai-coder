---
name: local-qa
description: Run local QA including formatting and linting for the repository. Use whenever any file has been updated, and install missing QA tools before rerunning.
disable-model-invocation: false
---

# Local QA (format and lint)

Run the local QA script `scripts/qa.sh` in this skill.

## Procedure

- Run `mise install` from the repository root before the QA script when the configured tools are missing.
- Execute the script after the mise-managed toolchain is available.
- Capture and summarize key output (success/failure, major warnings, and any files modified).
- If `mise install` fails or mise is unavailable, report exactly what failed and why instead of installing the same tools through another package manager.
