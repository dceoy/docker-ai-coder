# docker-ai-coder

Container configurations for AI coding agents

[![CI](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml)

## Docker image

Pull the image from [GitHub Container Registry](https://github.com/dceoy/docker-ai-coder/pkgs/container/ai-coder).

```sh
docker image pull ghcr.io/dceoy/ai-coder:latest
```


## Hermes Agent

The image includes [Hermes Agent](https://github.com/NousResearch/hermes-agent).
Its runtime state is stored in the shared `home-data` volume under
`/home/agent/.hermes`.

Run the setup wizard once:

```sh
docker compose run --rm hermes hermes setup
```

To use the Codex app-server runtime after selecting an OpenAI/Codex model:

```sh
docker compose run --rm hermes hermes codex-runtime codex_app_server
```

Start the persistent gateway service:

```sh
docker compose up -d hermes
```

For an interactive Hermes session:

```sh
docker compose run --rm hermes hermes
```

## Dependencies

Standalone CLI tools are managed with Mise. JavaScript dependencies are managed
with pnpm, and Python dependencies are managed with uv. Install the latest pnpm
and uv using their official installation scripts before installing the
locked tools and dependencies locally:

```sh
mise install --locked
pnpm install --frozen-lockfile
uv sync --locked --no-dev
```

pnpm also installs the project's pinned Node 24 runtime. Add
`node_modules/.bin` and `.venv/bin` to your PATH to run the installed tools.
The Docker image installs the latest pnpm and uv using their official scripts,
with pnpm under `/opt/pnpm` and uv under `/usr/local/bin`. Mise tools are installed
under `/opt/mise`, and pnpm and uv environments under `/opt/cli`, outside the
persistent home volume.

Update dependencies in `package.json` or `pyproject.toml`, then run
`pnpm install --lockfile-only` or `uv lock` and commit the resulting lockfile.
The package resolvers exclude releases newer than one day.

Standalone CLI versions, download URLs, and checksums are recorded in
`mise.lock`. Update a standalone tool with `mise lock --bump <tool>` and commit
the resulting lockfile with `mise.toml`.
