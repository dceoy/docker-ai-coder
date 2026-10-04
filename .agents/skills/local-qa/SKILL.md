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
- For repository-managed standalone tools such as `actionlint` and `zizmor`, run `mise install --locked` from the repository root. Do not install a separate copy with a platform package manager.
- Prefer the platform package manager for tools not managed by the repo:
  - macOS (Homebrew): `brew install shellcheck shfmt yamllint`
  - macOS `npx` fallback: `brew install node`
  - Linux (Debian/Ubuntu) base packages: `sudo apt-get update && sudo apt-get install -y shellcheck shfmt yamllint nodejs npm pipx`
  - Linux `checkov`: `pipx install checkov`
  - Linux `PATH` must include `~/.local/bin` before rerunning.
- If installation fails or a package manager is unavailable, report exactly what failed and why.
