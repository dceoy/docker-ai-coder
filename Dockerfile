# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=26.04
FROM public.ecr.aws/ubuntu/ubuntu:${UBUNTU_VERSION} AS base

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

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
        apt-file apt-utils build-essential ca-certificates curl git python3 rsync \
        tini tree unzip vim wget zsh

ENV MISE_DATA_DIR=/usr/local/share/mise
ENV MISE_CACHE_DIR=/var/cache/mise
ENV MISE_GLOBAL_CONFIG_FILE=/etc/mise/mise.toml
ENV NPM_CONFIG_MIN_RELEASE_AGE=7
ENV PLAYWRIGHT_BROWSERS_PATH=/usr/local/share/ms-playwright
ENV PATH="${MISE_DATA_DIR}/shims:${PATH}"

RUN \
      curl -fsSL https://mise.run \
        | env MISE_INSTALL_PATH=/usr/local/bin/mise sh

COPY mise.toml mise.lock /etc/mise/

RUN \
      --mount=type=cache,target=/var/cache/mise,sharing=locked \
      mise install

RUN \
      mkdir -p "${PLAYWRIGHT_BROWSERS_PATH}" \
      && playwright-cli install-browser chromium --with-deps \
      && chmod -R a+rX "${PLAYWRIGHT_BROWSERS_PATH}"

RUN \
      curl -fsSL -o /usr/local/bin/print-github-tags \
        https://raw.githubusercontent.com/dceoy/print-github-tags/master/print-github-tags \
      && chmod +x /usr/local/bin/print-github-tags

RUN \
      curl -fsSL -o /usr/local/bin/install.ohmyz.sh https://install.ohmyz.sh \
      && chmod +x /usr/local/bin/install.ohmyz.sh

RUN \
      curl -fsSL -o /usr/local/bin/claude.ai.install.sh https://claude.ai/install.sh \
      && chmod +x /usr/local/bin/claude.ai.install.sh

RUN \
      curl -fsSL -o /usr/local/bin/codex.install.sh https://chatgpt.com/codex/install.sh \
      && chmod +x /usr/local/bin/codex.install.sh

RUN \
      curl -fsSL -o /usr/local/bin/antigravity.install.sh https://antigravity.google/cli/install.sh \
      && chmod +x /usr/local/bin/antigravity.install.sh

RUN \
      curl -fsSL -o /usr/local/bin/cursor.install.sh https://cursor.com/install \
      && chmod +x /usr/local/bin/cursor.install.sh

RUN \
      curl -fsSL -o /usr/local/bin/opencode.install.sh https://opencode.ai/install \
      && chmod +x /usr/local/bin/opencode.install.sh

RUN \
      curl -fsSL -o /usr/local/bin/copilot.install.sh https://gh.io/copilot-install \
      && chmod +x /usr/local/bin/copilot.install.sh

RUN \
      mkdir -p /opt/agent \
      && chown "${USER_UID}:${USER_GID}" /opt/agent

RUN \
      groupadd --gid "${USER_GID}" "${USER_NAME}" \
      && useradd --uid "${USER_UID}" --gid "${USER_GID}" --shell /usr/bin/zsh --create-home "${USER_NAME}"

HEALTHCHECK NONE


FROM base AS cli

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'
ARG ZSH_THEME='nicoulaj'
ARG CLAUDE_CODE_VERSION='latest'
ARG CODEX_CLI_VERSION='latest'
ARG OPENCODE_VERSION='latest'
ARG GIT_USER_NAME='claude'
ARG GIT_USER_EMAIL='noreply@anthropic.com'

# hadolint ignore=DL3066
USER "${USER_NAME}"

WORKDIR "/home/${USER_NAME}"

ENV HOME="/home/${USER_NAME}"
ENV SHELL=/usr/bin/zsh
ENV PATH="/home/${USER_NAME}/.local/bin:/home/${USER_NAME}/.opencode/bin:${PATH}"

RUN \
      --mount=type=cache,target=/home/${USER_NAME}/.cache,uid="${USER_UID}",gid="${USER_GID}" \
      /usr/local/bin/claude.ai.install.sh "${CLAUDE_CODE_VERSION}"

# hadolint ignore=DL3059
RUN \
      --mount=type=cache,target=/home/${USER_NAME}/.cache,uid="${USER_UID}",gid="${USER_GID}" \
      CODEX_NON_INTERACTIVE=1 /usr/local/bin/codex.install.sh --release "${CODEX_CLI_VERSION}"

# hadolint ignore=DL3059
RUN \
      --mount=type=cache,target=/home/${USER_NAME}/.cache,uid="${USER_UID}",gid="${USER_GID}" \
      /usr/local/bin/antigravity.install.sh

# hadolint ignore=DL3059
RUN \
      --mount=type=cache,target=/home/${USER_NAME}/.cache,uid="${USER_UID}",gid="${USER_GID}" \
      /usr/local/bin/cursor.install.sh

# hadolint ignore=DL3059,DL4006,SC2015
RUN \
      --mount=type=cache,target=/home/${USER_NAME}/.cache,uid="${USER_UID}",gid="${USER_GID}" \
      [[ "${OPENCODE_VERSION}" != "latest" ]] \
      && /usr/local/bin/opencode.install.sh --version "${OPENCODE_VERSION}" \
      || curl -fsSL https://api.github.com/repos/anomalyco/opencode/releases/latest \
        | jq -r '.tag_name' \
        | xargs -t /usr/local/bin/opencode.install.sh --version

# hadolint ignore=DL3059
RUN \
      --mount=type=cache,target=/home/${USER_NAME}/.cache,uid="${USER_UID}",gid="${USER_GID}" \
      /usr/local/bin/copilot.install.sh

# hadolint ignore=DL3059
RUN \
      npx --yes skills@latest add microsoft/playwright-cli \
        --skill playwright-cli --global --agent claude-code --agent codex --agent universal --yes \
      && npx --yes skills@latest add vercel-labs/agent-browser \
        --skill agent-browser --global --agent claude-code --agent codex --agent universal --yes \
      && npx --yes skills@latest add herdrdev/herdr \
        --skill herdr --global --agent claude-code --agent codex --agent universal --yes \
      && npx --yes skills@latest add cloudflare/security-audit-skill \
        --skill security-audit --global --agent claude-code --agent codex --agent universal --yes \
      && npx --yes skills@latest add getsentry/skills \
        --skill security-review --global --agent claude-code --agent codex --agent universal --yes \
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
      rsync -a "${HOME}/" /opt/agent/

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
