#!/bin/bash
#
# ollama-check.sh — ensure the Ollama service is running.
#
# Used by the ollama-check systemd user timer. Pings the Ollama API; if it is
# not reachable, starts the user ollama.service (or launches `ollama serve` as
# a fallback). Exits 0 if Ollama is (or was just started and is now) reachable.
#
set -euo pipefail

OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
LOG_FILE="${OPENVIST_LOG_FILE:-$HOME/.local/share/opencode-see.log}"
TIMEOUT=10

log() {
    local ts level msg
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    level="$1"; shift
    msg="$*"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$ts] [$level] ollama-check: $msg" >> "$LOG_FILE" 2>/dev/null || true
}

# Is Ollama reachable right now?
is_running() {
    python3 - "$OLLAMA_URL" "$TIMEOUT" <<'PY' 2>/dev/null
import sys, urllib.request
url = sys.argv[1].rstrip('/') + '/api/tags'
try:
    with urllib.request.urlopen(url, timeout=int(sys.argv[2])) as r:
        r.read()
except Exception:
    sys.exit(1)
PY
}

if is_running; then
    log "INFO" "Ollama reachable at $OLLAMA_URL"
    exit 0
fi

log "WARN" "Ollama not reachable at $OLLAMA_URL — attempting to start it"

# Prefer the systemd user service if it exists.
if systemctl --user list-unit-files 2>/dev/null | grep -q '^ollama\.service'; then
    if systemctl --user start ollama.service 2>/dev/null; then
        log "INFO" "started ollama.service via systemctl --user"
    else
        log "ERROR" "systemctl --user start ollama.service failed"
    fi
else
    # Fallback: launch `ollama serve` detached in the background.
    if command -v ollama &>/dev/null; then
        nohup ollama serve >/dev/null 2>&1 &
        log "INFO" "launched 'ollama serve' in background (pid $!)"
    else
        log "ERROR" "ollama binary not found — cannot start it"
        echo "ollama-check: ollama not found. Install it: curl -fsSL https://ollama.com/install.sh | sh" >&2
        exit 1
    fi
fi

# Wait briefly and re-check.
for _ in 1 2 3 4 5; do
    sleep 2
    if is_running; then
        log "INFO" "Ollama now reachable at $OLLAMA_URL"
        exit 0
    fi
done

log "ERROR" "Ollama still not reachable after start attempt"
echo "ollama-check: Ollama did not come up. Check 'journalctl --user -u ollama' or run 'ollama serve' manually." >&2
exit 1
