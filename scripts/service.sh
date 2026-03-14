#!/usr/bin/env bash
# service.sh — manage the CodeMill OpenClaw launchd service
# Usage: service.sh <start|stop|restart|logs>
set -euo pipefail

PLIST_LABEL="com.codemill.agent"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/codemill-agent"
STDOUT_LOG="$LOG_DIR/stdout.log"
STDERR_LOG="$LOG_DIR/stderr.log"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[service]${NC} $*"; }
ok()   { echo -e "${GREEN}[service]${NC} $*"; }
warn() { echo -e "${YELLOW}[service]${NC} $*"; }
die()  { echo -e "${RED}[service] ERROR:${NC} $*" >&2; exit 1; }

CMD="${1:-}"
[[ -z "$CMD" ]] && { echo "Usage: service.sh <start|stop|restart|logs>"; exit 1; }

_is_loaded() {
  launchctl list | grep -q "$PLIST_LABEL" 2>/dev/null
}

_require_plist() {
  [[ -f "$PLIST_PATH" ]] || die "Plist not found at $PLIST_PATH — run setup.sh first."
}

case "$CMD" in
  start)
    _require_plist
    if _is_loaded; then
      warn "Service is already loaded. Use 'restart' to restart it."
    else
      launchctl load -w "$PLIST_PATH"
      ok "Service started."
    fi
    ;;

  stop)
    _require_plist
    if _is_loaded; then
      launchctl unload "$PLIST_PATH"
      ok "Service stopped."
    else
      warn "Service is not currently running."
    fi
    ;;

  restart)
    _require_plist
    log "Restarting service..."
    if _is_loaded; then
      launchctl unload "$PLIST_PATH"
    fi
    launchctl load -w "$PLIST_PATH"
    ok "Service restarted."
    ;;

  logs)
    mkdir -p "$LOG_DIR"
    echo -e "${CYAN}── stdout ($STDOUT_LOG) ─────────────────────────────────────${NC}"
    if [[ -f "$STDOUT_LOG" ]]; then
      tail -n 50 "$STDOUT_LOG"
    else
      warn "No stdout log yet."
    fi
    echo ""
    echo -e "${CYAN}── stderr ($STDERR_LOG) ─────────────────────────────────────${NC}"
    if [[ -f "$STDERR_LOG" ]]; then
      tail -n 50 "$STDERR_LOG"
    else
      warn "No stderr log yet."
    fi
    echo ""
    echo -e "${YELLOW}Tip:${NC} run ${CYAN}tail -f $STDOUT_LOG${NC} to follow live output."
    ;;

  status)
    if _is_loaded; then
      PID=$(launchctl list | awk -v label="$PLIST_LABEL" '$3 == label {print $1}')
      if [[ "$PID" == "-" || -z "$PID" ]]; then
        warn "Service is loaded but not running (last exit may have been non-zero)."
      else
        ok "Service is running (PID $PID)."
      fi
    else
      warn "Service is not loaded."
    fi
    ;;

  *)
    die "Unknown command: $CMD. Use: start | stop | restart | logs | status"
    ;;
esac
