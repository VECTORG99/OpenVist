#!/bin/bash
#
# uninstall.sh — OpenVist uninstaller.
#
# Removes installed scripts, the example config, and disables/removes the
# systemd cleanup timer. Screenshots and logs are left in place; pass
# --purge to remove those too.
#
set -euo pipefail

PURGE=0
if [[ "${1:-}" == "--purge" ]]; then
    PURGE=1
fi

echo "== OpenVist Uninstaller =="

# --- systemd timer ---------------------------------------------------------
echo "Disabling and removing systemd timers..."
if systemctl --user list-unit-files 2>/dev/null | grep -q opencode-ss-clean.timer; then
    systemctl --user disable --now opencode-ss-clean.timer 2>/dev/null || true
fi
if systemctl --user list-unit-files 2>/dev/null | grep -q ollama-check.timer; then
    systemctl --user disable --now ollama-check.timer 2>/dev/null || true
fi
rm -f "$HOME/.config/systemd/user/opencode-ss-clean.timer" \
      "$HOME/.config/systemd/user/opencode-ss-clean.service" \
      "$HOME/.config/systemd/user/ollama-check.timer" \
      "$HOME/.config/systemd/user/ollama-check.service" \
      "$HOME/.local/share/opencode-see/ollama-check.sh"
systemctl --user daemon-reload 2>/dev/null || true

# --- installed scripts -----------------------------------------------------
echo "Removing installed scripts..."
rm -f "$HOME/.local/bin/opencode-see" \
      "$HOME/.local/bin/vision_analyze.py"

# --- prompt templates ------------------------------------------------------
echo "Removing prompt templates..."
rm -rf "$HOME/.local/share/opencode-see/prompts"
rmdir "$HOME/.local/share/opencode-see" 2>/dev/null || true

# --- bash completion -------------------------------------------------------
echo "Removing bash completion..."
rm -f "$HOME/.local/share/bash-completion/completions/opencode-see"

# --- config ----------------------------------------------------------------
echo "Removing example config..."
rm -f "$HOME/.config/opencode-see/config.json"
rmdir "$HOME/.config/opencode-see" 2>/dev/null || true

# --- optional purge --------------------------------------------------------
if [[ "$PURGE" -eq 1 ]]; then
    echo "Purging screenshots and logs (--purge)..."
    rm -rf "$HOME/Pictures/opencode-ss"
    rm -f "$HOME/.local/share/opencode-see.log"
    rm -rf "$HOME/.local/share/opencode-see"
    rm -f "${XDG_RUNTIME_DIR:-/tmp}/opencode-latest-ss-path"
else
    echo "Left in place (use --purge to remove):"
    echo "  $HOME/Pictures/opencode-ss/"
    echo "  $HOME/.local/share/opencode-see.log"
    echo "  $HOME/.local/share/opencode-see/ (history)"
fi

echo ""
echo "Uninstall complete."
echo "You may also remove the pulled model with: ollama rm qwen2.5vl:7b"
