# docker-ai-coder

Container configurations for AI coding agents

[![CI](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml)

## Docker image

Pull the image from [GitHub Container Registry](https://github.com/dceoy/docker-ai-coder/pkgs/container/ai-coder).

```sh
docker image pull ghcr.io/dceoy/ai-coder:latest
```

## Hermes Agent

Hermes Agent is installed with its upstream installer. The release is managed
by Mise in `mise.toml`, and its persistent state is stored in the
`hermes-data` volume.

Run the setup wizard once:

```sh
docker compose run --rm hermes hermes setup
```

Then start the gateway:

```sh
docker compose up -d hermes
```

## Dependencies

Standalone CLI tools, including AWS CLI v2 and Google Cloud CLI, are managed
with Mise. JavaScript dependencies are managed with pnpm, and Python
dependencies are managed with uv. Install the latest pnpm
and uv using their official installation scripts before installing the
locked tools and dependencies locally:

```sh
mise install --locked
pnpm install --frozen-lockfile
uv sync --locked --no-dev
```

pnpm also installs the project's pinned Node 24 runtime and the pinned npm
CLI from `package.json`, which provides both `npm` and `npx`. In the Docker
image, uv downloads and manages the Python runtime required by `pyproject.toml`;
no system Node.js, npm, or Python packages are required. Add
`node_modules/.bin` and `.venv/bin` to your PATH to run the installed tools.

The Docker image installs the latest pnpm and uv using their official scripts,
with pnpm under `/opt/pnpm`, uv under `/usr/local/bin`, and uv-managed Python
under `/opt/uv/python`. The Mise configuration and lockfile sit alongside
`package.json` and `pyproject.toml` in `/opt/cli`; Mise-managed tools and state
are kept in `/opt/cli/.mise`. pnpm and uv project environments also live under
`/opt/cli`, outside the persistent home volume.

The build installs agent configuration and skills directly into `/opt/agent`
without duplicating a populated build home. Skills are stored once in
`.agents/skills` and linked into the Claude Code and Codex skill directories.
Playwright Chromium is installed in `/opt/cli/ms-playwright` rather than in
an agent home cache.

At runtime, `HOME` is `/home/agent`, backed by the `home-data` volume.
The image entrypoint seeds missing files from `/opt/agent` before starting
Herdr or Hermes, without overwriting existing files in older home volumes.

To refresh dependencies within declared version constraints, run:

```sh
pnpm update --lockfile-only --ignore-scripts --no-save
uv lock --upgrade
```

Dependabot monitors root npm and uv dependencies daily. The package resolvers
exclude releases newer than one day.

Standalone CLI versions and download URLs are recorded in `mise.lock`; checksum
recording depends on the selected backend.
Update a standalone tool with `mise lock --bump <tool>` and commit the resulting
lockfile with `mise.toml`.
