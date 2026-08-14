#!/bin/bash
#
# install.sh — OpenVist installer.
#
set -euo pipefail

echo "== OpenVist Installer =="

# --- dependency check ------------------------------------------------------
DEPS=(grim slurp hyprctl python3 ollama)
# ImageMagick: prefer `magick` (IMv7), accept legacy `convert`.
IMAGEMAGICK_OK=0
if command -v magick &>/dev/null || command -v convert &>/dev/null; then
    IMAGEMAGICK_OK=1
fi

MISSING=()
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done
if [[ "$IMAGEMAGICK_OK" -eq 0 ]]; then
    MISSING+=("imagemagick (magick/convert)")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Missing dependencies: ${MISSING[*]}"
    echo "Install them first:"
    echo "  sudo pacman -S grim slurp imagemagick python hyprland"
    echo "  curl -fsSL https://ollama.com/install.sh | sh"
    exit 1
fi

# --- install scripts -------------------------------------------------------
echo "Installing opencode-see + vision_analyze.py to ~/.local/bin/..."
mkdir -p "$HOME/.local/bin"
cp opencode-see "$HOME/.local/bin/opencode-see"
chmod +x "$HOME/.local/bin/opencode-see"
cp vision_analyze.py "$HOME/.local/bin/vision_analyze.py"
chmod +x "$HOME/.local/bin/vision_analyze.py"

# --- prompt templates ------------------------------------------------------
echo "Installing prompt templates to ~/.local/share/opencode-see/prompts/..."
mkdir -p "$HOME/.local/share/opencode-see/prompts"
cp prompts/*.txt "$HOME/.local/share/opencode-see/prompts/"

# --- bash completion -------------------------------------------------------
echo "Installing bash completion..."
mkdir -p "$HOME/.local/share/bash-completion/completions"
cp opencode-see-completion.bash \
    "$HOME/.local/share/bash-completion/completions/opencode-see"
echo "  Completion available after restarting your shell (or 'source ~/.local/share/bash-completion/completions/opencode-see')."

# --- example config --------------------------------------------------------
echo "Installing example config to ~/.config/opencode-see/..."
mkdir -p "$HOME/.config/opencode-see"
if [[ ! -f "$HOME/.config/opencode-see/config.json" ]]; then
    cp config.example.json "$HOME/.config/opencode-see/config.json"
    echo "  created config.json (edit to customize)"
else
    echo "  config.json already exists — left untouched"
fi

# --- systemd cleanup timer -------------------------------------------------
echo "Installing systemd cleanup timer..."
mkdir -p "$HOME/.config/systemd/user"
cp opencode-ss-clean.service "$HOME/.config/systemd/user/"
cp opencode-ss-clean.timer "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now opencode-ss-clean.timer

# --- systemd ollama-check timer (optional) ---------------------------------
echo "Installing optional Ollama auto-start timer..."
mkdir -p "$HOME/.local/share/opencode-see"
cp ollama-check.sh "$HOME/.local/share/opencode-see/ollama-check.sh"
chmod +x "$HOME/.local/share/opencode-see/ollama-check.sh"
cp ollama-check.service "$HOME/.config/systemd/user/"
cp ollama-check.timer "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now ollama-check.timer
echo "  Ollama will be checked every 5 min and started if not running."

# --- pull vision model -----------------------------------------------------
echo "Pulling qwen2.5vl:7b vision model..."
ollama pull qwen2.5vl:7b

# --- monitor configuration -------------------------------------------------
echo ""
echo "Configure your monitors:"
hyprctl monitors -j | python3 -c "
import sys, json
mons = json.load(sys.stdin)
for m in mons:
    side = 'left' if m['x'] == 0 else 'right'
    print(f'  {side}: {m[\"name\"]} ({m[\"width\"]}x{m[\"height\"]})')
"

read -r -p "Left monitor name: " LEFT
read -r -p "Right monitor name: " RIGHT

echo ""
echo "Add these to ~/.bashrc or ~/.zshrc:"
echo "  export LEFT_MON=$LEFT"
echo "  export RIGHT_MON=$RIGHT"
echo "  export VISION_MODEL=qwen2.5vl:7b"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "Done! Run: opencode-see [full|left|right|region|window]"
echo "Verify your setup with: opencode-see --check"
