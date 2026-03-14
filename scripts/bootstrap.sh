#!/usr/bin/env bash
# bootstrap.sh — entry point for setting up a CodeMill OpenClaw agent on a fresh Mac Mini
# Usage: curl -fsSL https://raw.githubusercontent.com/CodeMill-Solutions/codemill-agent-template/main/scripts/bootstrap.sh | bash -s -- https://github.com/CodeMill-Solutions/codemill-agent-klantnaam
set -euo pipefail

CLIENT_REPO_URL="${1:-}"
AGENT_DIR="$HOME/codemill-agent"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[bootstrap]${NC} $*"; }
ok()   { echo -e "${GREEN}[bootstrap]${NC} $*"; }
warn() { echo -e "${YELLOW}[bootstrap]${NC} $*"; }
die()  { echo -e "${RED}[bootstrap] ERROR:${NC} $*" >&2; exit 1; }

# ── Pre-flight ─────────────────────────────────────────────────────────────────
[[ -z "$CLIENT_REPO_URL" ]] && die "Usage: bootstrap.sh <client-repo-url>"
[[ "$(uname -s)" == "Darwin" ]] || die "This script is macOS-only."

log "Starting CodeMill agent bootstrap for: $CLIENT_REPO_URL"

# ── GitHub PAT (private repo) ──────────────────────────────────────────────────
# The token is used only to construct the authenticated clone URL.
# It is never written to disk, never exported, and unset immediately after use.
# /dev/tty is used explicitly so that read works even when the script is piped
# from curl (stdin is not a terminal in that case).
GITHUB_PAT=""
if [[ ! -d "$AGENT_DIR/.git" ]]; then
  echo -e "${CYAN}[bootstrap]${NC} De klantrepo is privé. Voer een GitHub Personal Access Token in."
  echo -e "             (Minimale scope: ${YELLOW}Contents: Read-only${NC} — token wordt niet opgeslagen)"
  read -rs -p "$(echo -e "${CYAN}[bootstrap]${NC} GitHub PAT: ")" GITHUB_PAT </dev/tty
  echo  # newline after silent read
  [[ -z "$GITHUB_PAT" ]] && die "Geen PAT ingevoerd — afgebroken."
fi

# ── 1. Homebrew ────────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
  ok "Homebrew already installed — skipping."
else
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Persist in shell profile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  fi
  ok "Homebrew installed."
fi

# Ensure brew is on PATH for the rest of this script
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ── 2. Node.js LTS via Homebrew ───────────────────────────────────────────────
if command -v node &>/dev/null; then
  ok "Node.js already installed — skipping. ($(node --version))"
else
  log "Installing Node.js LTS via Homebrew..."
  brew install node
  ok "Node.js LTS installed: $(node --version)"
fi

# ── 3. pnpm ────────────────────────────────────────────────────────────────────
if command -v pnpm &>/dev/null; then
  ok "pnpm already installed — skipping."
else
  log "Installing pnpm..."
  npm install -g pnpm
  ok "pnpm installed: $(pnpm --version)"
fi

# ── 4. OpenClaw ────────────────────────────────────────────────────────────────
if command -v openclaw &>/dev/null; then
  ok "OpenClaw already installed — skipping."
else
  log "Installing OpenClaw..."
  npm install -g @openclaw/cli
  ok "OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'version unknown')"
fi

# ── 5. Clone client repo ───────────────────────────────────────────────────────
if [[ -d "$AGENT_DIR/.git" ]]; then
  warn "Client repo already cloned at $AGENT_DIR — pulling latest..."
  git -C "$AGENT_DIR" pull --ff-only
else
  log "Cloning client repo to $AGENT_DIR..."

  # Embed the PAT into the HTTPS URL: https://<token>@github.com/org/repo
  # This avoids writing credentials to ~/.netrc or the git credential store.
  AUTHENTICATED_URL="${CLIENT_REPO_URL/https:\/\//https://${GITHUB_PAT}@}"

  # Clone — if it fails, unset the PAT before propagating the error
  git clone "$AUTHENTICATED_URL" "$AGENT_DIR" || {
    GITHUB_PAT=""
    unset GITHUB_PAT AUTHENTICATED_URL
    die "git clone mislukt. Controleer de repo-URL en de geldigheid van het PAT."
  }

  # Wipe credentials from memory and remove the token from the remote URL
  # so it is never stored in .git/config
  git -C "$AGENT_DIR" remote set-url origin "$CLIENT_REPO_URL"
  GITHUB_PAT=""
  unset GITHUB_PAT AUTHENTICATED_URL

  ok "Repo gecloned (token gewist uit geheugen en remote URL)."
fi

# ── 6. Hand off to setup.sh ────────────────────────────────────────────────────
SETUP_SCRIPT="$AGENT_DIR/scripts/setup.sh"
[[ -f "$SETUP_SCRIPT" ]] || die "setup.sh not found in cloned repo at $SETUP_SCRIPT"

chmod +x "$SETUP_SCRIPT"
log "Handing off to setup.sh..."
bash "$SETUP_SCRIPT"
