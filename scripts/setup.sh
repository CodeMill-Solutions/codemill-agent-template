#!/usr/bin/env bash
# setup.sh — post-clone setup for a CodeMill OpenClaw agent
# Run automatically by bootstrap.sh, or manually from ~/codemill-agent after cloning.
set -euo pipefail

AGENT_DIR="$HOME/codemill-agent"
OPENCLAW_CONFIG_DIR="$HOME/.openclaw/workspace/config"
PLIST_LABEL="com.codemill.agent"
PLIST_SRC="$AGENT_DIR/launchd/${PLIST_LABEL}.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[setup]${NC} $*"; }
ok()   { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[setup]${NC} $*"; }
die()  { echo -e "${RED}[setup] ERROR:${NC} $*" >&2; exit 1; }

cd "$AGENT_DIR"

# ── 1. pnpm install ────────────────────────────────────────────────────────────
log "Installing Node dependencies..."
pnpm install --frozen-lockfile 2>/dev/null || pnpm install
ok "Dependencies installed."

# ── 2. .env ────────────────────────────────────────────────────────────────────
if [[ -f "$AGENT_DIR/.env" ]]; then
  warn ".env already exists — skipping copy."
else
  cp "$AGENT_DIR/.env.example" "$AGENT_DIR/.env"
  ok "Copied .env.example → .env  (fill in your secrets!)"
fi

# ── 3. mcporter.json ──────────────────────────────────────────────────────────
log "Installing MCPorter config..."
mkdir -p "$OPENCLAW_CONFIG_DIR"
if [[ -f "$OPENCLAW_CONFIG_DIR/mcporter.json" ]]; then
  warn "mcporter.json already exists at $OPENCLAW_CONFIG_DIR — overwriting with repo version."
fi
cp "$AGENT_DIR/mcporter.json" "$OPENCLAW_CONFIG_DIR/mcporter.json"
ok "mcporter.json installed to $OPENCLAW_CONFIG_DIR"

# ── 4. launchd service ────────────────────────────────────────────────────────
mkdir -p "$HOME/Library/LaunchAgents"

# Expand $HOME in plist (plist does not support shell expansion)
sed "s|{{HOME}}|$HOME|g" "$PLIST_SRC" > "$PLIST_DEST"
ok "launchd plist installed to $PLIST_DEST"

# Unload first if already loaded (idempotent)
if launchctl list | grep -q "$PLIST_LABEL" 2>/dev/null; then
  log "Unloading existing launchd service..."
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

log "Loading launchd service..."
launchctl load -w "$PLIST_DEST"
ok "launchd service loaded and enabled."

# ── 5. self-improving-agent skill ─────────────────────────────────────────────
SKILL_DIR="$HOME/.openclaw/skills/self-improving-agent"

if [[ -d "$SKILL_DIR/.git" ]]; then
  warn "self-improving-agent skill already installed — skipping."
else
  log "Installing self-improving-agent skill..."
  if command -v clawhub &>/dev/null; then
    clawhub install self-improving-agent
  else
    git clone https://github.com/peterskoett/self-improving-agent.git "$SKILL_DIR"
  fi
  ok "self-improving-agent skill installed."
fi

# ── 6. .learnings workspace directory ─────────────────────────────────────────
LEARNINGS_DIR="$HOME/.openclaw/workspace/.learnings"
log "Creating .learnings directory..."
mkdir -p "$LEARNINGS_DIR"
ok ".learnings directory ready at $LEARNINGS_DIR"

# ── 7. Copy learning template files (skip if already present) ─────────────────
ASSETS_DIR="$SKILL_DIR/assets"
for template_file in LEARNINGS.md ERRORS.md FEATURE_REQUESTS.md; do
  dest="$LEARNINGS_DIR/$template_file"
  src="$ASSETS_DIR/$template_file"
  if [[ -f "$dest" ]]; then
    warn "$template_file already exists in .learnings — skipping."
  elif [[ -f "$src" ]]; then
    cp "$src" "$dest"
    ok "Copied $template_file → $LEARNINGS_DIR/"
  else
    warn "$src not found — skipping $template_file (skill may use a different layout)."
  fi
done

# ── 8. OpenClaw hooks ─────────────────────────────────────────────────────────
HOOKS_SRC="$SKILL_DIR/hooks/openclaw"
HOOKS_DEST="$HOME/.openclaw/hooks/self-improvement"

if [[ -d "$HOOKS_DEST" ]]; then
  warn "self-improvement hooks already installed — skipping."
elif [[ -d "$HOOKS_SRC" ]]; then
  log "Installing self-improvement OpenClaw hooks..."
  cp -r "$HOOKS_SRC" "$HOOKS_DEST"
  if command -v openclaw &>/dev/null; then
    openclaw hooks enable self-improvement
    ok "Hooks installed and enabled."
  else
    warn "Hooks copied but 'openclaw hooks enable' skipped — openclaw not on PATH yet."
  fi
else
  warn "Hooks source directory not found at $HOOKS_SRC — skipping hook install."
fi

# ── 9. Summary ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        CodeMill OpenClaw Agent — Setup complete          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next steps — ACTION REQUIRED:${NC}"
echo ""
echo -e "  1. Fill in ${CYAN}$AGENT_DIR/.env${NC}"
echo -e "     Required keys:"
echo -e "       • AZURE_OPENAI_API_KEY"
echo -e "       • AZURE_OPENAI_ENDPOINT"
echo -e "       • AZURE_OPENAI_DEPLOYMENT_NAME"
echo -e "       • YUKI_API_KEY + YUKI_DOMAIN_ID"
echo -e "       • BRAVE_API_KEY"
echo -e "       • GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET / GMAIL_REFRESH_TOKEN"
echo -e "       • GOOGLE_SERVICE_ACCOUNT_KEY_PATH (or JSON)"
echo ""
echo -e "  2. Verify MCP server config:"
echo -e "     ${CYAN}$OPENCLAW_CONFIG_DIR/mcporter.json${NC}"
echo ""
echo -e "  3. Restart the agent after editing .env:"
echo -e "     ${CYAN}bash $AGENT_DIR/scripts/service.sh restart${NC}"
echo ""
echo -e "  4. Check logs:"
echo -e "     ${CYAN}bash $AGENT_DIR/scripts/service.sh logs${NC}"
echo ""
echo -e "  5. Learning templates are at:"
echo -e "     ${CYAN}$HOME/.openclaw/workspace/.learnings/${NC}"
echo -e "     ${YELLOW}These files are local-only and are never committed to git.${NC}"
echo ""
