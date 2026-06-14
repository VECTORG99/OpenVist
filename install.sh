#!/bin/bash
set -e

echo "== OpenVist Installer =="

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

echo "Installing opencode-see to ~/.local/bin/..."
mkdir -p "$HOME/.local/bin"
cp opencode-see "$HOME/.local/bin/opencode-see"
chmod +x "$HOME/.local/bin/opencode-see"

echo "Installing systemd cleanup timer..."
mkdir -p "$HOME/.config/systemd/user"
cp opencode-ss-clean.service "$HOME/.config/systemd/user/"
cp opencode-ss-clean.timer "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now opencode-ss-clean.timer

echo "Pulling qwen2.5vl:7b vision model..."
ollama pull qwen2.5vl:7b

echo ""
echo "Configure your monitors:"
hyprctl monitors -j | python3 -c "
import sys, json
mons = json.load(sys.stdin)
for m in mons:
    side = 'left' if m['x'] == 0 else 'right'
    print(f'  {side}: {m[\"name\"]} ({m[\"width\"]}x{m[\"height\"]})')
"

read -p "Left monitor name: " LEFT
read -p "Right monitor name: " RIGHT

echo ""
echo "Add these to ~/.bashrc or ~/.zshrc:"
echo "  export LEFT_MON=$LEFT"
echo "  export RIGHT_MON=$RIGHT"
echo "  export VISION_MODEL=qwen2.5vl:7b"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "Done! Run: opencode-see [full|left|right|region|window]"
