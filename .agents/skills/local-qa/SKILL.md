---
name: local-qa
description: Run local QA including formatting and linting for the repository. Use whenever any file has been updated, and install missing QA tools before rerunning.
disable-model-invocation: false
---

# Local QA (format and lint)

Run the local QA script `scripts/qa.sh` in this skill.

## Procedure

- Execute the script exactly as shown above when this skill is triggered.
- Capture and summarize key output (success/failure, major warnings, and any files modified).
- If the script fails due to missing tooling, install the missing tool(s) and rerun the script once.
- YAML linting uses the root project's `uv.lock`-pinned yamllint. If needed, run `uv sync --locked` from the repository root; do not install yamllint separately through Homebrew or apt.
- Install pnpm and uv with their official standalone installers if either is missing.
- Install mise using the platform's supported installation method if it is missing.
- Use `mise install --locked shellcheck shfmt actionlint jq yq` from the repository root to install the locked CLI tools (including Go-based `mikefarah/yq`).
- Run the QA script with mise-managed tools on `PATH`, e.g. `mise exec -- bash .agents/skills/local-qa/scripts/qa.sh`.
- If installation fails or a package manager is unavailable, report exactly what failed and why.
