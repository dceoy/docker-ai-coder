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
- Prefer the platform package manager for the remaining tools used by this repo:
  - macOS (Homebrew): `brew install shellcheck shfmt actionlint`
  - Linux (Debian/Ubuntu) base packages: `sudo apt-get update && sudo apt-get install -y shellcheck golang rustc cargo`
  - Linux `actionlint`: `go install github.com/rhysd/actionlint/cmd/actionlint@latest`
  - Linux `shfmt`: install the upstream release binary or use an available platform package.
  - Linux `PATH` must include `~/.local/bin`, `~/go/bin`, and `~/.cargo/bin` before rerunning.
- If installation fails or a package manager is unavailable, report exactly what failed and why.
