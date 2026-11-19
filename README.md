# docker-ai-coder

Container configurations for AI coding agents

[![CI](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/docker-ai-coder/actions/workflows/ci.yml)

## Docker Hardened Images

The image builds on Docker Hardened Images Community Debian 13 (`dhi.io/debian-base:trixie-dev`) to preserve the interactive shell and APT toolchain. Authenticate with Docker Hub credentials before building locally:

```sh
docker login dhi.io
```

For GitHub Actions builds, configure the repository secret `DOCKER_TOKEN` with a Docker Hub access token. The reusable workflow logs in to DHI using that token and continues to publish to GHCR with `GITHUB_TOKEN`.

## Docker image

Pull the image from [GitHub Container Registry](https://github.com/dceoy/docker-ai-coder/pkgs/container/ai-coder).

```sh
docker image pull ghcr.io/dceoy/ai-coder:latest
```

## Muse Code

Muse Code is installed using Meta's official Linux installer. Its binaries live
in `/opt/cli/muse/bin` (on `PATH`), outside the persistent `home-data`
volume, so it is available with both new and existing volumes. Muse Code's
login and session state are stored under the persistent runtime home.

Verify the installation and start an interactive session in `/workspace`:

```sh
docker compose run --rm herdr muse --version
docker compose run --rm herdr muse
```

On first use, trust the workspace and sign in through the offered browser flow
or API-key option. To run a one-off prompt without interactive authentication,
set `META_API_KEY` in the host environment and forward it only to that run:

```sh
docker compose run --rm -e META_API_KEY herdr muse exec "Summarize this repository"
```

The API key is not baked into the image or injected into every Compose service.
The existing container security settings are unchanged; Muse Code's additional
Linux sandbox features may depend on the host's Docker and namespace restrictions.
See the [Muse Code documentation](https://dev.meta.ai/docs/muse-code).

## Hermes Agent

Hermes Agent is installed with its upstream installer. The release is managed
by Mise in `mise.toml`, and its persistent state is stored in the
`hermes-data` volume.

Run the setup wizard once:

```sh
docker compose run --rm hermes hermes setup
```

Then start the gateway for messaging use:

```sh
docker compose up -d hermes
```

### Browser UI (Webapp)

The Hermes gateway can serve the Desktop-style Webapp without another service.
The Compose port is bound to the host's loopback interface at
`http://127.0.0.1:9120`, not exposed to the LAN or internet. The Webapp
requires a sign-in provider because it listens on `0.0.0.0` *inside* Docker.

Add the following values to your local `.env` (already gitignored), using
`openssl rand -hex 24` to generate a password and `openssl rand -hex 32`
for a stable session-signing secret:

```dotenv
HERMES_UI_USER=admin
HERMES_UI_PASSWORD=<generated-password>
HERMES_UI_SECRET=<generated-session-secret>
```

Protect the file with `chmod 600 .env`. Do not commit the credentials.
The credentials are optional for other Compose services; if the Webapp is
enabled without a valid sign-in provider, Hermes refuses to serve it.

After running the one-time `hermes setup` command above, enable the Webapp in
the persistent `hermes-data` volume:

```sh
docker compose run --rm hermes hermes config set webapp.enabled true
docker compose run --rm hermes hermes config set webapp.host 0.0.0.0
docker compose run --rm hermes hermes config set webapp.port 9120
docker compose run --rm hermes hermes config set webapp.public_url http://localhost:9120
docker compose up -d --force-recreate hermes
docker compose exec hermes hermes webapp --status
```

Open `http://localhost:9120` on the Docker host and sign in with the
configured credentials. For a remote Docker host, keep the port private and
forward it over SSH rather than publishing it publicly:

```sh
ssh -L 9120:127.0.0.1:9120 user@remote-host
```

The Webapp and messaging clients use the same gateway and persistent data.
For a terminal UI, use `docker compose exec -it hermes hermes --tui`.
The separate management Dashboard on port 9119 is not enabled here: the
custom image uses `tini`, not the upstream image's s6 supervisor.

## Codex app server

Create a dedicated token for incoming WebSocket connections:

```sh
export CODEX_WS_TOKEN="$(openssl rand -hex 32)"
```

For API key authentication, set `OPENAI_API_KEY` in your environment and store
it in the shared home volume before starting the server:

```sh
docker compose run --rm codex-app-server sh -c \
  'printenv OPENAI_API_KEY | codex login --with-api-key'
```

Skip that login step if the shared home already contains Codex credentials.
The API key authenticates outbound model requests and is separate from the
inbound WebSocket token. Then start the server:

```sh
docker compose up -d codex-app-server
```

The WebSocket endpoint is available at `ws://127.0.0.1:4500` on the host.
Compose mounts `CODEX_WS_TOKEN` as a secret file and the server requires
capability-token authentication. Clients must send
`Authorization: Bearer <CODEX_WS_TOKEN>` during the WebSocket handshake, replacing
the placeholder with the token value. Keep the token securely for clients and
subsequent container recreations. To rotate it, export a new value and run
`docker compose up -d --force-recreate codex-app-server`.

## Runtime isolation

All Compose services inherit security settings from `herdr`: they run as the
unprivileged `agent` user, drop all Linux capabilities, and disallow
gaining privileges with `no-new-privileges`. These controls also apply to
`hermes` and `codex-app-server` through Compose `extends`. Persistent volumes
and the writable workspace are unchanged.

The optional `AI_CODER_PIDS_LIMIT` environment variable sets each service's
PIDs cgroup limit. It defaults to `-1` (unlimited) to avoid breaking parallel
coding agents and Chromium workers without workload measurements. For example,
`AI_CODER_PIDS_LIMIT=2048 docker compose up -d` enables a limit after verifying
the task/thread count under representative workloads.

These settings reduce privilege escalation risk, but do **not**
isolate credentials between agents. The shared `home-data` volume may contain
CLI login state, and `GH_TOKEN` / `ANTHROPIC_API_KEY` remain available to
the services that receive them. Do not run untrusted multi-tenant workloads
under this configuration. Separate service homes and a credential broker would
require a migration plan and are not implemented here.

## Dependencies

Go, Rust, and standalone CLI tools, including AWS CLI v2 and Google Cloud CLI,
are managed with Mise. JavaScript dependencies are managed with pnpm, and Python
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
Rust toolchains use `RUSTUP_HOME=/opt/cli/rustup` and Cargo uses
`CARGO_HOME=/opt/cli/cargo`, so both remain available with an existing initialized
home volume. Cargo-installed binaries in `/opt/cli/cargo/bin` are on `PATH`.

The build installs agent configuration and skills directly into `/opt/agent`
without duplicating a populated build home. Skills are stored once in
`.agents/skills` and linked into the Claude Code and Codex skill directories.
Playwright Chromium is installed in `/opt/cli/ms-playwright` rather than in
an agent home cache.

At runtime, `HOME` is `/home/agent`, backed by the `home-data` volume.
On the first start of a home volume, `entrypoint.sh` seeds missing files
from `/opt/agent` before starting Herdr or Hermes and records an initialization
marker. It uses `flock` to serialize initialization when containers share
`home-data`. It also registers `/workspace` as a Git safe directory without
adding duplicate entries. Later container recreations preserve the home volume,
including user edits and intentional deletions. Existing volumes are initialized
without overwriting their files. Do not use `docker compose down -v` if you
want to keep your configuration.

Dockerfile input files are staged with BuildKit `RUN --mount=type=bind`,
rather than `COPY` or `ADD`.

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
