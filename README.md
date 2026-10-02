# docker-ai-coder

Container configurations for AI coding agents

[![CI](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml)

## Docker image

Pull the image from [GitHub Container Registry](https://github.com/dceoy/docker-ai-coder/pkgs/container/ai-coder).

```sh
docker image pull ghcr.io/dceoy/ai-coder:latest
```

## Dependencies

Standalone CLI tools are managed with Mise. JavaScript dependencies are managed
with pnpm 11.28.3, and Python dependencies are managed with uv 0.12.22. Install
pnpm and uv using their official installation scripts before installing the
locked tools and dependencies locally:

```sh
mise install --locked
pnpm install --frozen-lockfile
uv sync --locked --no-dev
```

pnpm also installs the project's pinned Node 24 runtime. Add
`node_modules/.bin` and `.venv/bin` to your PATH to run the installed tools.
The Docker image installs pnpm and uv using their official scripts, with pnpm
under `/opt/pnpm` and uv under `/usr/local/bin`. Mise tools are installed under
`/opt/mise`, and pnpm and uv environments under `/opt/cli`, outside the persistent
home volume.

Update dependencies in `package.json` or `pyproject.toml`, then run
`pnpm install --lockfile-only` or `uv lock` and commit the resulting lockfile.
The package resolvers exclude releases newer than one day.

Standalone CLI versions, download URLs, and checksums are recorded in
`mise.lock`. Update a standalone tool with `mise lock --bump <tool>` and commit
the resulting lockfile with `mise.toml`.
