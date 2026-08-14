#!/usr/bin/env python3
"""
OpenVist - Vision analysis helper.

Base64-encodes an image and sends it to a local Ollama vision model for
description. Designed to be called by the `opencode-see` bash script but can
also be used and tested independently.

Usage:
    python3 vision_analyze.py <image_path> [prompt]

Environment overrides:
    OLLAMA_URL            Ollama API base URL (default: http://127.0.0.1:11434)
    VISION_MODEL          Model name (default: qwen2.5vl:7b)
    VISION_TIMEOUT        Request timeout in seconds (default: 120)
    VISION_NUM_CTX        Context window size (default: 4096)
    OPENVIST_COMPARE_IMAGE  Optional second image path for comparison mode.
                          When set, both images are sent to the model and the
                          prompt is framed as a comparison request.
    OPENVIST_BANNER       Optional footer string appended to the analysis
                          output (e.g. "Analyzed by OpenVist v1.1.0 | model").
"""

import base64
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_MODEL = "qwen2.5vl:7b"
DEFAULT_URL = "http://127.0.0.1:11434"
DEFAULT_TIMEOUT = 120
DEFAULT_NUM_CTX = 4096
DEFAULT_PROMPT = "Describe in detail what you see on this computer screen"


def _env_int(name, default):
    """Read an integer from an environment variable, falling back to default."""
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        return int(raw)
    except ValueError:
        print(f"warning: invalid integer for {name}={raw!r}, using {default}",
              file=sys.stderr)
        return default


def load_config():
    """Build the configuration from environment variables with defaults."""
    return {
        "model": os.environ.get("VISION_MODEL", DEFAULT_MODEL),
        "url": os.environ.get("OLLAMA_URL", DEFAULT_URL).rstrip("/"),
        "timeout": _env_int("VISION_TIMEOUT", DEFAULT_TIMEOUT),
        "num_ctx": _env_int("VISION_NUM_CTX", DEFAULT_NUM_CTX),
    }


def encode_image(path):
    """Read an image file and return its base64-encoded string."""
    try:
        with open(path, "rb") as f:
            return base64.b64encode(f.read()).decode()
    except FileNotFoundError:
        raise RuntimeError(f"image file not found: {path}")
    except PermissionError:
        raise RuntimeError(f"permission denied reading image: {path}")
    except OSError as exc:
        raise RuntimeError(f"could not read image {path}: {exc}")


def analyze(image_path, prompt=None, config=None, compare_image=None):
    """
    Send an image (and optionally a second comparison image) to Ollama and
    return the model's text description.

    When compare_image is given, both images are sent and the prompt is framed
    as a comparison between the two screenshots.

    Raises RuntimeError with a human-readable message on any failure.
    """
    config = config or load_config()
    prompt = prompt or DEFAULT_PROMPT

    images = [encode_image(image_path)]

    if compare_image:
        images.append(encode_image(compare_image))
        prompt = (
            "I am showing you two screenshots of a computer screen, "
            "the first one is the earlier state and the second one is the "
            "current state. Compare them and describe what changed between "
            "them. Focus on differences: new/removed windows, text changes, "
            "error messages, cursor position, and any other notable changes. "
            "If nothing changed, say so.\n\n"
            f"Additional instructions: {prompt}"
        )

    payload = json.dumps({
        "model": config["model"],
        "prompt": prompt,
        "stream": False,
        "options": {"num_ctx": config["num_ctx"]},
        "images": images,
    }).encode()

    endpoint = f"{config['url']}/api/generate"
    req = urllib.request.Request(
        endpoint,
        data=payload,
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=config["timeout"]) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        body = ""
        try:
            body = exc.read().decode(errors="replace").strip()
        except Exception:
            pass
        raise RuntimeError(
            f"Ollama returned HTTP {exc.code} {exc.reason}"
            + (f": {body}" if body else "")
        )
    except urllib.error.URLError as exc:
        raise RuntimeError(
            f"cannot reach Ollama at {endpoint}: {exc.reason}. "
            "Is `ollama serve` running?"
        )
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Ollama returned invalid JSON: {exc}")
    except TimeoutError:
        raise RuntimeError(
            f"Ollama request timed out after {config['timeout']}s"
        )

    response = data.get("response", "").strip()
    if not response:
        raise RuntimeError("Ollama returned an empty response")
    return response


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if argv and len(argv) > 1 and argv[1] in ("-h", "--help") else 2

    image_path = argv[1]
    prompt = " ".join(argv[2:]) if len(argv) > 2 else None
    compare_image = os.environ.get("OPENVIST_COMPARE_IMAGE") or None

    try:
        result = analyze(image_path, prompt, compare_image=compare_image)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # pragma: no cover - unexpected safety net
        print(f"unexpected error: {exc}", file=sys.stderr)
        return 1

    print(result)
    banner = os.environ.get("OPENVIST_BANNER")
    if banner:
        print(f"\n---\n_{banner}_")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
