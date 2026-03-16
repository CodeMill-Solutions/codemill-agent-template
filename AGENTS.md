# AGENTS.md — AI Coding Conventions

This file defines conventions and constraints for AI coding assistants (Claude, Copilot, etc.) working in this repository.

---

## Project context

This is a **per-client deployment repository** for CodeMill B.V.'s OpenClaw AI agent platform. Each client receives their own private clone of this template. The agent runs as a launchd service on an Apple Silicon Mac Mini.

Key facts:
- **Runtime:** macOS (Apple Silicon), launchd service
- **LLM:** Azure OpenAI (no Ollama, no local models)
- **MCP:** MCPorter config at `~/.openclaw/workspace/config/mcporter.json`
- **Secrets:** always via `.env`, never hardcoded, never committed
- **Node package manager:** pnpm exclusively — never npm or yarn

---

## Non-negotiable rules

1. **Never commit secrets.** `.env` is gitignored. `.env.example` must have empty values only.
2. **Never add Ollama or local LLM references.** This stack is Azure OpenAI only.
3. **Never change the package manager from pnpm.** Use `pnpm` for all Node operations.
4. **Never modify `.gitignore` to include `.env`.** It must always stay ignored.
5. **Shell scripts must be POSIX-compatible bash** (`#!/usr/bin/env bash`, `set -euo pipefail`).
6. **Scripts must be idempotent.** Running them multiple times must not break anything.
7. **`{{HOME}}` placeholder in the plist** is intentional — `setup.sh` replaces it with the actual path. Do not substitute it with a hardcoded path.

---

## File conventions

### Shell scripts (`scripts/`)
- Shebang: `#!/usr/bin/env bash`
- Always start with `set -euo pipefail`
- Use colour-coded logging helpers: `log()`, `ok()`, `warn()`, `die()`
- Check idempotently before performing actions (e.g. `command -v`, `-d`, `-f` guards)
- Prefer `[[` over `[` for conditionals

### JSON config files
- All secrets referenced as `"${VAR_NAME}"` — never literal values
- Indent with 2 spaces
- No trailing commas

### Plist (`launchd/`)
- Use `{{HOME}}` as a placeholder for the home directory — `setup.sh` performs the substitution with `sed`
- Do not use `~` in plist values; it is not expanded by launchd

### Markdown docs
- `docs/onboarding-klant.md` is client-facing and written in **Dutch**
- `docs/new-client-checklist.md` is internal and written in **Dutch**
- `README.md` and `AGENTS.md` are in **English**

---

## What belongs where

| What | Where |
|---|---|
| Client secrets & credentials | `.env` (gitignored, on-device only) |
| MCP server definitions | `mcporter.json` (committed, env vars for secrets) |
| Agent LLM / behaviour config | `agent.config.json` (committed, env vars for secrets) |
| launchd service definition | `launchd/com.codemill.agent.plist` |
| Bootstrap / setup / service management | `scripts/` |
| Client-facing docs (NL) | `docs/onboarding-klant.md` |
| Internal ops docs (NL) | `docs/new-client-checklist.md` |
| Client-specific skills | `skills/<skill-name>/` (committed, installed to `~/.openclaw/skills/`) |
| Client-specific plugins | `plugins/<plugin-name>/` (committed, installed to `~/.openclaw/plugins/`) |
| Learnings, errors, feature requests | `~/.openclaw/workspace/.learnings/` (local-only, never committed) |

---

## Self-Improvement

This project uses the **self-improving-agent** skill from ClawHub. Use it actively:

- **Log errors and corrections** to `~/.openclaw/workspace/.learnings/ERRORS.md` when something goes wrong or required correction.
- **Log reusable insights** to `~/.openclaw/workspace/.learnings/LEARNINGS.md` — patterns, gotchas, and decisions that would be useful next time.
- **Log feature ideas** to `~/.openclaw/workspace/.learnings/FEATURE_REQUESTS.md` for improvements to the agent setup itself.
- **Consult `.learnings/LEARNINGS.md` before starting complex tasks** — known patterns and past decisions live there.
- **Promote broadly applicable learnings** to `SOUL.md`, `AGENTS.md`, or `TOOLS.md` when a pattern is stable enough to be a standing convention.

The `.learnings/` directory is gitignored — its contents are local to each client machine and must never be committed or pushed.

---

## Things to avoid

- Do not add a `package.json` `"scripts"` section that duplicates what `scripts/*.sh` already does
- Do not add a Docker or containerisation layer — the agent runs natively via launchd
- Do not add CI/CD pipelines to this repo — deployments are triggered by `bootstrap.sh`
- Do not abstract shell logic prematurely — three explicit checks beat one clever helper
- Do not add comments explaining what code does when the code is self-evident
