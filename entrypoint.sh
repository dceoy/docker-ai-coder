#!/usr/bin/env bash
set -euo pipefail

(
  flock -x 9

  if [[ ! -e "${HOME}/.docker-ai-coder-initialized" ]]; then
    rsync -a --ignore-existing /opt/agent/ "${HOME}/"
    if ! git config --global --get core.excludesfile > /dev/null; then
      git config --global core.excludesfile "${HOME}/.gitignore"
    fi
    touch "${HOME}/.docker-ai-coder-initialized"
  fi

  if ! git config --global --get-all safe.directory | grep -Fxq -- /workspace; then
    git config --global --add safe.directory /workspace
  fi
) 9>"${HOME}/.docker-ai-coder-init.lock"

exec "${@}"
