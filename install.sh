#!/bin/bash
set -e

echo "== OpenVist Installer =="

# Check dependencies
DEPS=(grim slurp hyprctl convert python3 ollama)
MISSING=()
for dep in "${DEPS[@]}"; do
  if ! command -v "$dep" &>/dev/null; then
    MISSING+=("$dep")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Missing dependencies: ${MISSING[*]}"
  echo "Install them first:"
  echo "  sudo pacman -S grim slurp imagemagick python hyprutils"
  echo "  curl -fsSL https://ollama.com/install.sh | sh"
  exit 1
fi

# Install script
echo "Installing opencode-see to ~/.local/bin/..."
mkdir -p "$HOME/.local/bin"
cp opencode-see "$HOME/.local/bin/opencode-see"
chmod +x "$HOME/.local/bin/opencode-see"

# Install systemd timer
echo "Installing systemd cleanup timer..."
mkdir -p "$HOME/.config/systemd/user"
cp opencode-ss-clean.service "$HOME/.config/systemd/user/"
cp opencode-ss-clean.timer "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now opencode-ss-clean.timer

# Pull vision model (user chooses)
echo ""
echo "Available vision models:"
echo "  1) qwen2.5vl:7b  (6.0 GB) - best quality, recommended"
echo "  2) llava:7b      (4.5 GB) - good quality"
echo "  3) moondream     (1.6 GB) - fast but basic"
echo ""
read -p "Which model? [1]: " MODEL_CHOICE
case "$MODEL_CHOICE" in
  2) MODEL="llava:7b" ;;
  3) MODEL="moondream" ;;
  *) MODEL="qwen2.5vl:7b" ;;
esac

echo "Pulling $MODEL (this may take a while)..."
ollama pull "$MODEL"

# Configure monitors
echo ""
echo "Configuring monitors..."
hyprctl monitors -j | python3 -c "
import sys, json
mons = json.load(sys.stdin)
for m in mons:
    side = 'left' if m['x'] == 0 else 'right'
    print(f'  {side}: {m[\"name\"]} ({m[\"width\"]}x{m[\"height\"]})')
"

read -p "Left monitor name [DP-2]: " LEFT
LEFT="${LEFT:-DP-2}"
read -p "Right monitor name [DP-3]: " RIGHT
RIGHT="${RIGHT:-DP-3}"

echo ""
echo "Add these to your shell rc (~/.bashrc, ~/.zshrc):"
echo "  export LEFT_MON=$LEFT"
echo "  export RIGHT_MON=$RIGHT"
echo "  export VISION_MODEL=$MODEL"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "Done! Run: opencode-see [full|left|right|region|window]"
echo "Or use the 'see' command in your Discord bot (see README)"
