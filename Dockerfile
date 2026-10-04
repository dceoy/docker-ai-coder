# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=26.04
FROM public.ecr.aws/ubuntu/ubuntu:${UBUNTU_VERSION} AS base

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ENV NPM_CONFIG_MIN_RELEASE_AGE=1
ENV MISE_CACHE_DIR=/opt/mise/cache
ENV MISE_CONFIG_DIR=/opt/mise/config
ENV MISE_DATA_DIR=/opt/mise/data
ENV MISE_GLOBAL_CONFIG_FILE=/opt/mise/mise.toml
ENV MISE_STATE_DIR=/opt/mise/state
ENV PNPM_HOME=/opt/pnpm
ENV PATH="/opt/mise/data/shims:/opt/cli/bin:/opt/cli/node_modules/.bin:/opt/cli/.venv/bin:/opt/pnpm/bin:${PATH}"

RUN \
      rm -f /etc/apt/apt.conf.d/docker-clean \
      && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
        > /etc/apt/apt.conf.d/keep-cache

# hadolint ignore=DL3008
RUN \
      --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      apt-get -yqq update \
      && apt-get -yqq upgrade \
      && apt-get -yqq install --no-install-recommends --no-install-suggests \
        apt-file apt-utils awscli bats build-essential ca-certificates curl extrepo file gh git gnupg jq nodejs npm \
        python3 python3-venv ripgrep rsync shellcheck shfmt tini tree unzip vim wget yamllint zsh \
      && ln -s python3 /usr/bin/python

RUN \
      extrepo enable mise \
      && curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
      && . /etc/os-release \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${UBUNTU_CODENAME} main" \
        > /etc/apt/sources.list.d/hashicorp.list \
      && curl -fsSL https://get.trivy.dev/deb/public.key \
        | gpg --dearmor -o /usr/share/keyrings/trivy.gpg \
      && echo 'deb [signed-by=/usr/share/keyrings/trivy.gpg] https://get.trivy.dev/deb generic main' \
        > /etc/apt/sources.list.d/trivy.list

# hadolint ignore=DL3008
RUN \
      --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      apt-get -yqq update \
      && apt-get -yqq install --no-install-recommends --no-install-suggests mise terraform trivy

RUN \
      curl -fsSL https://astral.sh/uv/install.sh \
        | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh \
      && curl -fsSL https://get.pnpm.io/install.sh \
        | env SHELL=/bin/bash sh -

RUN \
      curl -fsSL -o /usr/local/bin/print-github-tags \
        https://raw.githubusercontent.com/dceoy/print-github-tags/master/print-github-tags \
      && chmod +x /usr/local/bin/print-github-tags

RUN \
      curl -fsSL -o /usr/local/bin/install.ohmyz.sh https://install.ohmyz.sh \
      && chmod +x /usr/local/bin/install.ohmyz.sh

RUN \
      mkdir -p /opt/agent /opt/mantis /opt/cli /opt/mise /opt/pnpm \
      && chown "${USER_UID}:${USER_GID}" /opt/agent /opt/mantis /opt/cli /opt/mise \
      && chown -R "${USER_UID}:${USER_GID}" /opt/pnpm

RUN \
      groupadd --gid "${USER_GID}" "${USER_NAME}" \
      && useradd --uid "${USER_UID}" --gid "${USER_GID}" --shell /usr/bin/zsh --create-home "${USER_NAME}"

HEALTHCHECK NONE


FROM base AS mise-tools

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'

# hadolint ignore=DL3066
USER "${USER_NAME}"
WORKDIR "/home/${USER_NAME}"

ENV HOME="/home/${USER_NAME}"
ENV PATH="/opt/mise/data/shims:/home/${USER_NAME}/.local/bin:/home/${USER_NAME}/.opencode/bin:${PATH}"

RUN \
      --mount=type=bind,source=mise.toml,target=/tmp/mise.toml \
      --mount=type=bind,source=mise.lock,target=/tmp/mise.lock \
      mkdir -p /opt/mise \
      && cat /tmp/mise.toml > /opt/mise/mise.toml \
      && cat /tmp/mise.lock > /opt/mise/mise.lock

RUN \
      --mount=type=cache,target=/opt/mise/cache,uid="${USER_UID}",gid="${USER_GID}",sharing=locked \
      mise lock http:cursor-agent \
      && printf '%s\n' 'CURSOR_MISE_LOCK_BEGIN' \
      && cat /opt/mise/mise.lock \
      && printf '%s\n' 'CURSOR_MISE_LOCK_END' \
      && mise install --locked \
      && mkdir -p /opt/cli/bin \
      && printf '%s\n' \
        '#!/bin/sh' \
        'set -eu' \
        'tool_dir="$(mise where http:cursor-agent)"' \
        'PATH="${tool_dir}:${PATH}"' \
        'export PATH' \
        'exec "${tool_dir}/agent" "$@"' \
        > /opt/cli/bin/agent \
      && chmod +x /opt/cli/bin/agent \
      && ln -s agent /opt/cli/bin/cursor-agent \
      && rm -f /opt/mise/data/shims/agent /opt/mise/data/shims/node /opt/mise/data/shims/rg


FROM mise-tools AS dependencies

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'

# hadolint ignore=DL3066
USER "${USER_NAME}"
WORKDIR /opt/cli

ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=never

COPY --chown=${USER_UID}:${USER_GID} package.json pnpm-lock.yaml pnpm-workspace.yaml pyproject.toml uv.lock ./

# Keep the pnpm store in the image: the managed Node runtime links into it.
RUN \
      pnpm install --frozen-lockfile --store-dir /opt/pnpm/store

RUN \
      --mount=type=cache,target=/home/${USER_NAME}/.cache/uv,uid="${USER_UID}",gid="${USER_GID}",sharing=locked \
      uv sync --locked --no-dev --python /usr/bin/python3

# hadolint ignore=DL3002,DL3066
USER root

RUN \
      playwright install-deps chromium


FROM dependencies AS cli

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'
ARG ZSH_THEME='nicoulaj'
ARG GIT_USER_NAME='claude'
ARG GIT_USER_EMAIL='noreply@anthropic.com'

# hadolint ignore=DL3066
USER "${USER_NAME}"

WORKDIR "/home/${USER_NAME}"

ENV HOME="/home/${USER_NAME}"
ENV MANTIS_HOME=/opt/mantis
ENV SHELL=/usr/bin/zsh
ENV PATH="/opt/mise/data/shims:/opt/cli/node_modules/.bin:/opt/cli/.venv/bin:/opt/pnpm/bin:/home/${USER_NAME}/.local/bin:/home/${USER_NAME}/.opencode/bin:${PATH}"

RUN \
      git clone --depth=1 https://github.com/google/mantis.git "${MANTIS_HOME}" \
      && "${MANTIS_HOME}/reference/install.sh"

# hadolint ignore=DL3059
RUN \
      playwright-cli install-browser chromium

RUN \
      mkdir -p "${HOME}/.vim/autoload" \
      && curl -fsSL -o "${HOME}/.vim/autoload/plug.vim" \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# hadolint ignore=DL3059
RUN \
      skills add microsoft/playwright-cli \
        --skill playwright-cli --global --agent claude-code --agent codex --agent universal --yes \
      && skills add vercel-labs/agent-browser \
        --skill agent-browser --global --agent claude-code --agent codex --agent universal --yes \
      && skills add herdrdev/herdr \
        --skill herdr --global --agent claude-code --agent codex --agent universal --yes \
      && skills add cloudflare/security-audit-skill \
        --skill security-audit --global --agent claude-code --agent codex --agent universal --yes \
      && skills add getsentry/skills \
        --skill security-review --global --agent claude-code --agent codex --agent universal --yes \
      && skills add google/mantis \
        --skill '*' --global --agent claude-code --agent codex --agent universal --yes \
      && skills add cloudflare/skills \
        --skill '*' --global --agent claude-code --agent codex --agent universal --yes \
      && mkdir -p "${HOME}/.playwright" \
      && jq -n '{browser: {browserName: "chromium", launchOptions: {chromiumSandbox: false}}}' \
        > "${HOME}/.playwright/cli.config.json"

# hadolint ignore=SC2016
RUN \
      /usr/local/bin/install.ohmyz.sh --unattended \
      && sed -ie "s/^ZSH_THEME=.*/ZSH_THEME='${ZSH_THEME}'/g" ~/.zshrc \
      && rm -f ~/.zshrce \
      && { \
        echo 'alias l="ls"'; \
        echo 'alias g="git"'; \
        echo 'alias v="vim"'; \
      } >> ~/.zprofile

RUN \
      echo '.DS_Store' > "${HOME}/.gitignore" \
      && git config --global color.ui auto \
      && git config --global core.excludesfile "${HOME}/.gitignore" \
      && git config --global core.pager '' \
      && git config --global core.quotepath false \
      && git config --global core.precomposeunicode false \
      && git config --global gui.encoding utf-8 \
      && git config --global fetch.prune true \
      && git config --global push.default matching \
      && git config --global user.name "${GIT_USER_NAME}" \
      && git config --global user.email "${GIT_USER_EMAIL}"

RUN \
      mkdir -p "${HOME}/.config/herdr" \
      && printf '\n[terminal]\nshell_mode = "login"\n' \
        >> "${HOME}/.config/herdr/config.toml" \
      && rsync -a "${HOME}/" /opt/agent/

RUN \
      export CLAUDE_CONFIG_DIR='/opt/agent/.claude' \
      && claude plugin marketplace add --scope=user anthropics/claude-plugins-official \
      && claude plugin install --scope=user claude-security@claude-plugins-official \
      && claude plugin install --scope=user security-guidance@claude-plugins-official \
      && claude plugin marketplace add --scope=user anthropics/knowledge-work-plugins \
      && claude plugin marketplace add --scope=user openai/codex-plugin-cc \
      && claude plugin install --scope=user codex@openai-codex

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["herdr", "server"]
