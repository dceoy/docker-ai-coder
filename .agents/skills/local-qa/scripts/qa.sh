#!/usr/bin/env bash

set -euox pipefail
cd "$(git rev-parse --show-toplevel)"

COOLDOWN_DAYS=7
export UV_EXCLUDE_NEWER="${COOLDOWN_DAYS} days"
export NPM_CONFIG_MIN_RELEASE_AGE="${COOLDOWN_DAYS}"
export PNPM_CONFIG_MINIMUM_RELEASE_AGE=$((COOLDOWN_DAYS * 24 * 60))

# Markdown and JSON
npx -y prettier --write './**/*.{md,json}'

# YAML
git ls-files -z -- '*.yml' \
  | xargs -0 -t uvx yamllint -d '{"extends": "relaxed", "rules": {"line-length": "disable"}}'

# Shell scripts
git ls-files -z -- '*.sh' '*.bash' '*.bats' \
  | xargs -0 -t shfmt --write --indent=2 --binary-next-line --case-indent --space-redirects
git ls-files -z -- '*.sh' '*.bash' '*.bats' \
  | xargs -0 -t shellcheck

# GitHub Actions
zizmor --fix=safe .github/workflows
git ls-files -z -- '.github/workflows/*.yml' | xargs -0 -t actionlint
checkov --framework=all --output=github_failed_only --directory=.
