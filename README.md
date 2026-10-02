# docker-ai-coder

Container configurations for AI coding agents

[![CI](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml)

## Docker image

Pull the image from [GitHub Container Registry](https://github.com/dceoy/docker-ai-coder/pkgs/container/ai-coder).

```sh
docker image pull ghcr.io/dceoy/ai-coder:latest
```

## Dependencies

JavaScript CLI dependencies are managed with pnpm 11.28.3, and Python CLI
dependencies are managed with uv. Install the locked dependencies locally with:

```sh
pnpm install --frozen-lockfile
uv sync --locked --no-dev
```

pnpm also installs the project's pinned Node 24 runtime. Add
`node_modules/.bin` and `.venv/bin` to your PATH to run the installed tools.
The Docker image installs both environments under `/opt/cli`, outside the
persistent home volume.

Update dependencies in `package.json` or `pyproject.toml`, then run
`pnpm install --lockfile-only` or `uv lock` and commit the resulting lockfile.
Both resolvers exclude releases newer than one day.

Standalone CLI versions, Linux ARM64/AMD64 download URLs, and SHA-256 checksums
are recorded in `tools.json`. When updating these tools, update the version,
URLs, and checksums together. The image runs `scripts/install-tools.sh` to
verify each download before installing its executables.
