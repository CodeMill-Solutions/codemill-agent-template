# codemill-agent-template

Template repository for deploying a **CodeMill OpenClaw AI Agent** on an Apple Silicon Mac Mini. Each client receives their own private clone of this repo.

---

## Quick start — fresh Mac Mini

Run this single command on the target machine to install all dependencies and set up the agent:

```bash
sudo curl -fsSL https://raw.githubusercontent.com/CodeMill-Solutions/codemill-agent-template/main/scripts/bootstrap.sh | bash -s -- <client-repo-url>
```

Replace `<client-repo-url>` with the SSH or HTTPS URL of the client's private repo (e.g. `git@github.com:CodeMill-Solutions/codemill-agent-acme.git`).

After the script completes, fill in `~/codemill-agent/.env` and restart the service:

```bash
bash ~/codemill-agent/scripts/service.sh restart
```

---

## What bootstrap does

1. Installs **Homebrew** (if not present)
2. Installs **Node.js LTS** via Homebrew
3. Installs **pnpm** (via npm) and **OpenClaw**
4. Prompts for a GitHub PAT to clone the private client repo
5. Clones the client repo to `~/codemill-agent`
6. Calls `scripts/setup.sh` to finish configuration

## What setup does

1. Runs `pnpm install`
2. Copies `.env.example` → `.env` (if `.env` doesn't exist yet)
3. Installs `mcporter.json` to `~/.openclaw/workspace/config/`
4. Registers and starts the **launchd** service
5. Installs the **self-improving-agent** skill (via ClawHub or git clone)
6. Creates `~/.openclaw/workspace/.learnings/` and copies the learning templates
7. Installs and enables the OpenClaw self-improvement hooks
8. Prints a summary of remaining manual steps

---

## Managing the service

```bash
bash ~/codemill-agent/scripts/service.sh start
bash ~/codemill-agent/scripts/service.sh stop
bash ~/codemill-agent/scripts/service.sh restart
bash ~/codemill-agent/scripts/service.sh logs
bash ~/codemill-agent/scripts/service.sh status
```

---

## Repository structure

```
codemill-agent-template/
├── scripts/
│   ├── bootstrap.sh        # Entry point — run via curl on a bare Mac Mini
│   ├── setup.sh            # Post-clone setup (called by bootstrap.sh)
│   └── service.sh          # launchd service management
├── launchd/
│   └── com.codemill.agent.plist   # launchd service definition
├── docs/
│   ├── onboarding-klant.md        # Client-facing guide (Dutch)
│   └── new-client-checklist.md    # Internal ops checklist (Dutch)
├── .learnings/
│   └── .gitkeep            # Tracks directory; *.md files are gitignored (local-only)
├── mcporter.json           # MCP server configuration (MCPorter format)
├── agent.config.json       # OpenClaw agent config (Azure OpenAI)
├── .env.example            # Template for required environment variables
├── .gitignore              # Excludes .env, learnings, and other sensitive files
├── AGENTS.md               # AI coding conventions for this repo
└── README.md               # This file
```

---

## Configuration

### Environment variables (`.env`)

Copy `.env.example` to `.env` and fill in all values. See the inline comments in `.env.example` for details on each variable.

Required keys:
- `AZURE_OPENAI_API_KEY` / `AZURE_OPENAI_ENDPOINT` / `AZURE_OPENAI_DEPLOYMENT_NAME`
- `YUKI_API_KEY` / `YUKI_DOMAIN_ID`
- `BRAVE_API_KEY`
- `GMAIL_CLIENT_ID` / `GMAIL_CLIENT_SECRET` / `GMAIL_REFRESH_TOKEN`
- `GOOGLE_SERVICE_ACCOUNT_KEY_PATH` / `GOOGLE_WORKSPACE_DOMAIN` / `GOOGLE_WORKSPACE_ADMIN_EMAIL`

**Never commit `.env`** — it is listed in `.gitignore`.

### MCP servers (`mcporter.json`)

Pre-configured servers:
| Server | Package |
|---|---|
| Yuki (accounting) | `@codemill-solutions/yuki-mcp` |
| Brave Search | `@modelcontextprotocol/server-brave-search` |
| Gmail | `@modelcontextprotocol/server-gmail` |
| Google Workspace | `@modelcontextprotocol/server-google-workspace` |

All API keys are read from environment variables — no secrets are stored in this file.

---

## Skills

### self-improving-agent

The agent is equipped with the [self-improving-agent](https://github.com/peterskoett/self-improving-agent) skill, which gives it a structured memory layer for learnings, errors, and feature requests.

| Path | Purpose |
|---|---|
| `~/.openclaw/skills/self-improving-agent/` | Skill source, installed by `setup.sh` |
| `~/.openclaw/workspace/.learnings/LEARNINGS.md` | Reusable patterns and past decisions |
| `~/.openclaw/workspace/.learnings/ERRORS.md` | Logged mistakes and their corrections |
| `~/.openclaw/workspace/.learnings/FEATURE_REQUESTS.md` | Ideas for improving the agent setup |

**Learnings are always local.** The `.learnings/*.md` files are gitignored and will never be committed or pushed to the client repo. Only the `.learnings/.gitkeep` file (which tracks the directory itself) is version-controlled.

---

## Creating a new client repo

1. Create a new **private** GitHub repo under `CodeMill-Solutions` (e.g. `codemill-agent-acme`)
2. Use this template as the starting point
3. Follow `docs/new-client-checklist.md` for the full internal setup process

---

## Docs

- [Client onboarding guide (NL)](docs/onboarding-klant.md)
- [New client checklist — internal (NL)](docs/new-client-checklist.md)
- [AI coding conventions](AGENTS.md)

---

## Requirements

- macOS 14 Sonoma or later (Apple Silicon)
- Internet access during bootstrap
- SSH key or HTTPS credentials for cloning the client repo

---

*Built by [CodeMill B.V.](https://codemill.nl)*
