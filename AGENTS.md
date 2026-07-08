# Repository Guidelines

## Key Components

- **Dockerfile**: Defines a multi-stage build for creating an Ubuntu-based container with Python, Node.js, and various AI tools
- **compose.yml**: Docker Compose configuration for running the container

## Available AI Tools

The container comes pre-installed with:

- Anthropic Claude Code
- OpenAI Codex CLI
- Cursor CLI
- OpenCode
- Playwright CLI

## Working with the Repository

### Building the Container

```sh
docker compose build --pull
```

### Running the Container

```sh
docker compose run --rm devcontainer -l
```

### Code Quality and Documentation

**Important**: Run these before committing or creating a PR.

- **format and lint**: Use `local-qa` skill.

## Commit & Pull Request Guidelines

- Run QA checks using `local-qa` skill before committing or creating a PR.
- Execute relevant tests for modified code before committing (if applicable).
- Keep PRs focused and include: concise summary, affected workflow paths, linked issue/context, and regenerated `README.md` when workflow inventory changes.
- Branch names use appropriate prefixes on creation (e.g., `feature/...`, `bugfix/...`, `refactor/...`, `docs/...`, `chore/...`).
- When instructed to create a PR, create it as a draft with appropriate labels by default.

## Code Design Principles

Always prefer the simplest design that works.

- **KISS**: Choose straightforward solutions and avoid unnecessary abstraction.
- **DRY**: Remove duplication when it improves clarity and maintainability.
- **YAGNI**: Do not add features, hooks, or flexibility until they are needed.
- **SOLID/Clean Code**: Apply these as tools, only when they keep the design simpler and easier to change.

## Development Methodology

Keep delivery incremental, test-backed, and easy to review.

- Make small, safe, reversible changes.
- Prefer `Red -> Green -> Refactor`.
- Do not mix feature work and refactoring in the same commit.
- Refactor when it improves clarity or removes real duplication (Rule of Three).
- Keep tests fast, focused, and self-validating.
