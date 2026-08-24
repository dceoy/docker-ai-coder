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
- Prefer the platform package manager for missing tools used by this repo:
  - macOS (Homebrew): `brew install shellcheck actionlint yamllint checkov zizmor`
  - macOS `npx` fallback: `brew install node`
  - Linux (Debian/Ubuntu) base packages: `sudo apt-get update && sudo apt-get install -y shellcheck yamllint nodejs npm pipx golang rustc cargo`
  - Linux `checkov`: `pipx install checkov`
  - Linux `actionlint`: `go install github.com/rhysd/actionlint/cmd/actionlint@latest`
  - Linux `zizmor`: `cargo install zizmor`
  - Linux `PATH` must include `~/.local/bin`, `~/go/bin`, and `~/.cargo/bin` before rerunning.
- If installation fails or a package manager is unavailable, report exactly what failed and why.
