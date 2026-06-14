# OpenVist

Local screen capture and AI vision analysis for Wayland/Hyprland.

Takes a screenshot, sends it to a local vision model (via Ollama), and returns a detailed description. Designed for Discord bot integration via the `/see` command.

## Requirements

- **Wayland compositor** (Hyprland recommended)
- **grim** + **slurp** — screenshot tools
- **ImageMagick** (`convert`) — image resizing
- **Ollama** — local LLM server
- **Python 3** — vision model client
- **systemd (user)** — cleanup timer (optional)

Install dependencies:
```bash
sudo pacman -S grim slurp imagemagick python hyprutils
curl -fsSL https://ollama.com/install.sh | sh
```

## Quick Install

```bash
git clone https://github.com/VECTORG99/OpenVist.git
cd OpenVist
chmod +x install.sh
./install.sh
```

The installer will:
1. Copy `opencode-see` to `~/.local/bin/`
2. Set up the systemd cleanup timer
3. Prompt for the vision model to download
4. Help configure monitor names

## Usage

```bash
# Full screen (both monitors)
opencode-see full

# Single monitor
LEFT_MON=DP-2 RIGHT_MON=DP-3 opencode-see left
LEFT_MON=DP-2 RIGHT_MON=DP-3 opencode-see right

# Region select (click and drag)
opencode-see region

# Active window
opencode-see window

# Custom prompt
opencode-see full "Find and read any error messages on screen"
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `LEFT_MON` | `DP-2` | Left monitor name (from `hyprctl monitors`) |
| `RIGHT_MON` | `DP-3` | Right monitor name |
| `VISION_MODEL` | `qwen2.5vl:7b` | Ollama vision model to use |

### Output

The script prints:
1. `Screen capture: /home/user/Pictures/opencode-ss/ss-20260614-120000.jpg`
2. The AI-generated description of what is on screen

The screenshot path is also written to `/tmp/opencode-latest-ss-path` for bot integration.

## Discord Bot Integration

Add `see-command.js` to your Discord.js bot's command directory and register it in your command index.

The `/see` slash command provides:

- `/see mode:both` — capture both monitors
- `/see mode:left` — left monitor only (higher detail)
- `/see mode:right` — right monitor only (higher detail)
- `/see mode:region` — click-and-drag selection
- `/see mode:window` — active window only

The bot sends the AI description as text plus the screenshot image as a Discord attachment.

## Auto-Cleanup

Screenshots are saved to `~/Pictures/opencode-ss/`. A systemd user timer deletes files older than 5 minutes:

```bash
# Check timer status
systemctl --user status opencode-ss-clean.timer

# Trigger cleanup manually
systemctl --user start opencode-ss-clean.service
```

## Available Vision Models

| Model | Size | Quality |
|---|---|---|
| `qwen2.5vl:7b` | 6.0 GB | Excellent — reads text, detailed |
| `llava:7b` | 4.5 GB | Good |
| `moondream` | 1.6 GB | Fast but basic |

Smaller text is better readable when capturing a single monitor (`left` / `right` mode) at full resolution.

## Security

- **100% local** — no data leaves your machine
- Screenshots auto-delete after 5 minutes
- Uses Ollama API on `127.0.0.1:11434`
- No cloud services, no API keys required

## File Structure

```
OpenVist/
├── opencode-see              Main screenshot + vision script
├── see-command.js            Discord.js bot command reference
├── opencode-ss-clean.service systemd cleanup service
├── opencode-ss-clean.timer   systemd cleanup timer
├── install.sh                Installation script
└── README.md                 This file
```

## License

MIT
