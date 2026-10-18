# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=26.04
FROM public.ecr.aws/ubuntu/ubuntu:${UBUNTU_VERSION} AS base

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ENV MISE_CACHE_DIR=/opt/cli/.mise/cache
ENV MISE_CONFIG_DIR=/opt/cli/.mise/config
ENV MISE_DATA_DIR=/opt/cli/.mise/data
ENV MISE_GLOBAL_CONFIG_FILE=/opt/cli/mise.toml
ENV MISE_STATE_DIR=/opt/cli/.mise/state
ENV PNPM_HOME=/opt/pnpm
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python
ENV UV_PYTHON_PREFERENCE=only-managed
ENV PATH="/opt/cli/.mise/data/shims:/opt/cli/node_modules/.bin:/opt/cli/.venv/bin:/opt/pnpm/bin:${PATH}"

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
        apt-file apt-utils bats build-essential ca-certificates curl extrepo ffmpeg file git gnupg jq \
        libffi-dev ripgrep rsync shellcheck shfmt tini tree unzip vim wget zsh

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
        > /etc/apt/sources.list.d/trivy.list \
      && curl -fsSL -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list

# hadolint ignore=DL3008
RUN \
      --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      apt-get -yqq update \
      && apt-get -yqq install --no-install-recommends --no-install-suggests gh mise terraform trivy \
      && gh skill --help > /dev/null

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
      curl -fsSL -o /usr/local/bin/cursor.install.sh https://cursor.com/install \
      && chmod +x /usr/local/bin/cursor.install.sh

RUN \
      mkdir -p /opt/agent /opt/cli/.mise /var/lib/hermes /opt/pnpm /opt/uv \
      && chown "${USER_UID}:${USER_GID}" /opt/agent /opt/cli /opt/cli/.mise /var/lib/hermes /opt/uv \
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
WORKDIR /opt/agent

ENV HOME=/opt/agent
ENV PATH="/opt/cli/.mise/data/shims:/opt/agent/.local/bin:/opt/agent/.opencode/bin:${PATH}"

ENV UV_LINK_MODE=copy

# The ARM64 Google Cloud SDK requires Python while mise installs its tools.
RUN \
      --mount=type=bind,source=pyproject.toml,target=/tmp/pyproject.toml \
      --mount=type=bind,source=uv.lock,target=/tmp/uv.lock \
      --mount=type=cache,target=/opt/agent/.cache/uv,uid="${USER_UID}",gid="${USER_GID}",sharing=locked \
      cp /tmp/pyproject.toml /tmp/uv.lock /opt/cli/ \
      && uv sync --project /opt/cli --locked --no-dev \
      && python --version

# hadolint ignore=DL4006
RUN \
      --mount=type=bind,source=mise.toml,target=/tmp/mise.toml \
      --mount=type=bind,source=mise.lock,target=/tmp/mise.lock \
      --mount=type=cache,target=/opt/cli/.mise/cache,uid="${USER_UID}",gid="${USER_GID}",sharing=locked \
      cp /tmp/mise.toml /tmp/mise.lock /opt/cli/ \
      && mise install --locked \
      && aws --version 2>&1 | grep -q '^aws-cli/2[.]' \
      && gcloud --version > /dev/null


FROM mise-tools AS dependencies

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'

# hadolint ignore=DL3066
USER "${USER_NAME}"
WORKDIR /opt/cli

# Keep the pnpm store in the image: the managed Node runtime links into it.
RUN \
      --mount=type=bind,source=package.json,target=/tmp/package.json \
      --mount=type=bind,source=pnpm-lock.yaml,target=/tmp/pnpm-lock.yaml \
      --mount=type=bind,source=pnpm-workspace.yaml,target=/tmp/pnpm-workspace.yaml \
      cp /tmp/package.json /tmp/pnpm-lock.yaml /tmp/pnpm-workspace.yaml /opt/cli/ \
      && pnpm install --frozen-lockfile --store-dir /opt/pnpm/store \
      && node --version \
      && npm --version \
      && npx --version

RUN \
      HERMES_VERSION="$(mise tool github:NousResearch/hermes-agent --requested)" \
      && env -u UV_PYTHON_PREFERENCE mise exec -- install.sh --branch "v${HERMES_VERSION}" --dir /opt/cli/hermes \
        --hermes-home /var/lib/hermes --skip-setup --skip-browser

# hadolint ignore=DL3002,DL3066
USER root

RUN \
      ln -s /opt/cli/hermes/venv/bin/hermes /usr/local/bin/hermes \
      && playwright install-deps chromium


FROM dependencies AS cli

ARG USER_NAME='agent'
ARG USER_UID='1001'
ARG USER_GID='1001'
ARG ZSH_THEME='nicoulaj'
ARG GIT_USER_NAME='claude'
ARG GIT_USER_EMAIL='noreply@anthropic.com'

# hadolint ignore=DL3066
USER "${USER_NAME}"

WORKDIR /opt/agent

ENV HOME=/opt/agent
ENV SHELL=/usr/bin/zsh
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/cli/ms-playwright
ENV PATH="/opt/cli/.mise/data/shims:/opt/cli/node_modules/.bin:/opt/cli/.venv/bin:/opt/pnpm/bin:/opt/agent/.local/bin:/opt/agent/.opencode/bin:${PATH}"

# hadolint ignore=DL3059
RUN \
      playwright-cli install-browser chromium \
      && test -d "${PLAYWRIGHT_BROWSERS_PATH}"

RUN \
      --mount=type=cache,target=/opt/agent/.cache,uid="${USER_UID}",gid="${USER_GID}" \
      /usr/local/bin/cursor.install.sh \
      && for name in agent cursor-agent; do \
        link="${HOME}/.local/bin/${name}" \
        && target="$(readlink -f "${link}")" \
        && ln -sfn "$(realpath --relative-to="$(dirname "${link}")" "${target}")" "${link}" || exit 1; \
      done

RUN \
      mkdir -p "${HOME}/.vim/autoload" \
      && curl -fsSL -o "${HOME}/.vim/autoload/plug.vim" \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# hadolint ignore=DL3059
RUN \
      --mount=type=secret,id=GH_TOKEN,env=GH_TOKEN,required=true \
      gh skill install microsoft/playwright-cli skills/playwright-cli --scope user --agent universal --force \
      && gh skill install vercel-labs/agent-browser skills/agent-browser --scope user --agent universal --force \
      && gh skill install herdrdev/herdr skills/herdr --scope user --agent universal --force \
      && gh skill install cloudflare/security-audit-skill skills/security-audit --scope user --agent universal --force \
      && gh skill install getsentry/skills skills/security-review --scope user --agent universal --force \
      && gh skill install cloudflare/skills --all --scope user --agent universal --force \
      && mkdir -p "${HOME}/.claude" "${HOME}/.codex" "${HOME}/.playwright" \
      && ln -s ../.agents/skills "${HOME}/.claude/skills" \
      && ln -s ../.agents/skills "${HOME}/.codex/skills" \
      && test -d "${HOME}/.claude/skills" \
      && test -d "${HOME}/.codex/skills" \
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
      && git config --global core.excludesfile '~/.gitignore' \
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
        >> "${HOME}/.config/herdr/config.toml"

RUN \
      export CLAUDE_CONFIG_DIR='/opt/agent/.claude' \
      && claude plugin marketplace add --scope=user anthropics/claude-plugins-official \
      && claude plugin install --scope=user claude-security@claude-plugins-official \
      && claude plugin install --scope=user security-guidance@claude-plugins-official \
      && claude plugin marketplace add --scope=user anthropics/knowledge-work-plugins \
      && claude plugin marketplace add --scope=user openai/codex-plugin-cc \
      && claude plugin install --scope=user codex@openai-codex \
      && for metadata in \
        "${CLAUDE_CONFIG_DIR}/plugins/installed_plugins.json" \
        "${CLAUDE_CONFIG_DIR}/plugins/known_marketplaces.json"; do \
        test -s "${metadata}" \
        && sed -i "s|${HOME}/|/home/${USER_NAME}/|g" "${metadata}" \
        && jq empty "${metadata}" \
        && ! grep -Fq "${HOME}/" "${metadata}" || exit 1; \
      done

ENV HOME="/home/${USER_NAME}"
ENV PATH="/home/${USER_NAME}/.local/bin:/home/${USER_NAME}/.opencode/bin:${PATH}"
WORKDIR "/home/${USER_NAME}"

RUN \
      --mount=type=bind,source=entrypoint.sh,target=/tmp/entrypoint.sh \
      install -m 0755 /tmp/entrypoint.sh /opt/cli/entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/cli/entrypoint.sh"]
CMD ["herdr", "server"]
