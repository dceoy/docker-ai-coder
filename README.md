# docker-ai-coder

Container configurations for AI coding agents

[![CI](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml)

## Docker image

Pull the image from [GitHub Container Registry](https://github.com/dceoy/docker-ai-coder/pkgs/container/ai-coder).

```sh
docker image pull ghcr.io/dceoy/ai-coder:latest
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
under `/opt/uv/python`. Mise tools are installed under `/opt/mise`, and the
pnpm and uv project environments live under `/opt/cli`, outside the persistent
home volume.

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
