#!/usr/bin/env python3
"""
OpenVist - Vision analysis helper.

Base64-encodes an image and sends it to a local Ollama vision model for
description. Designed to be called by the `opencode-see` bash script but can
also be used and tested independently.

Usage:
    python3 vision_analyze.py <image_path> [prompt] [--retry N] [--json]

Flags:
    --retry N   Number of attempts for the Ollama request (default: 1, no retry).
                Connection and timeout errors are retried; model/HTTP errors are
                not, since retrying will not fix them.
    --json      Emit a machine-readable JSON object instead of plain text:
                {"screenshot","model","prompt","description","timestamp","duration_ms"}
    --help      Show this help and exit.

Environment overrides:
    OLLAMA_URL            Ollama API base URL (default: http://127.0.0.1:11434)
    VISION_MODEL          Model name (default: qwen2.5vl:7b)
    VISION_TIMEOUT        Request timeout in seconds (default: 120)
    VISION_NUM_CTX        Context window size (default: 4096)
    OPENVIST_RETRY        Number of attempts (default: 1)
    OPENVIST_COMPARE_IMAGE  Optional second image path for comparison mode.
                          When set, both images are sent to the model and the
                          prompt is framed as a comparison request.
    OPENVIST_BANNER       Optional footer string appended to the analysis
                          output (e.g. "Analyzed by OpenVist v1.1.0 | model").
                          Ignored in --json mode.
"""

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

DEFAULT_MODEL = "qwen2.5vl:7b"
DEFAULT_URL = "http://127.0.0.1:11434"
DEFAULT_TIMEOUT = 120
DEFAULT_NUM_CTX = 4096
DEFAULT_RETRY = 1
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
        "retries": _env_int("OPENVIST_RETRY", DEFAULT_RETRY),
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


def _friendly_http_error(exc, model, body):
    """Turn an HTTPError into an actionable, human-readable message."""
    if exc.code == 404:
        return (
            f"Model '{model}' not found in Ollama. "
            f"Run 'ollama pull {model}' to download it."
        )
    if exc.code == 400:
        # Often caused by a non-vision model receiving images.
        return (
            f"Ollama rejected the request (HTTP 400): {body or exc.reason}. "
            f"Make sure '{model}' is a vision-capable model "
            f"(e.g. 'ollama pull qwen2.5vl:7b')."
        )
    if exc.code == 500:
        return (
            f"Ollama returned an internal error (HTTP 500): {body or exc.reason}. "
            "Check 'ollama serve' logs; the model may have crashed or run out of memory."
        )
    return (
        f"Ollama returned HTTP {exc.code} {exc.reason}"
        + (f": {body}" if body else "")
    )


def _friendly_url_error(exc, endpoint):
    """Turn a URLError into an actionable, human-readable message."""
    reason = getattr(exc, "reason", str(exc))
    return (
        f"Cannot reach Ollama at {endpoint}: {reason}. "
        "Is 'ollama serve' running? Start it with 'ollama serve' or "
        "'systemctl --user start ollama'."
    )


def _do_request(config, payload, endpoint):
    """Perform a single Ollama request. Raises RuntimeError on failure."""
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
        raise RuntimeError(_friendly_http_error(exc, config["model"], body))
    except urllib.error.URLError as exc:
        raise RuntimeError(_friendly_url_error(exc, endpoint))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Ollama returned invalid JSON: {exc}")
    except TimeoutError:
        raise RuntimeError(
            f"Ollama request timed out after {config['timeout']}s. "
            "Increase VISION_TIMEOUT or use a smaller model "
            "('ollama pull qwen2.5vl:3b')."
        )

    response = data.get("response", "").strip()
    if not response:
        raise RuntimeError(
            "Ollama returned an empty response. The model may be loading; "
            "try again or check 'ollama ps'."
        )
    return response


def _is_retryable(message):
    """Heuristic: only connection/timeout errors are worth retrying."""
    needles = ("Cannot reach Ollama", "timed out", "Cannot connect")
    return any(n in message for n in needles)


def analyze(image_path, prompt=None, config=None, compare_image=None, retries=None):
    """
    Send an image (and optionally a second comparison image) to Ollama and
    return the model's text description.

    When compare_image is given, both images are sent and the prompt is framed
    as a comparison between the two screenshots.

    `retries` overrides the configured attempt count (>=1). Connection and
    timeout errors are retried with a short backoff; model/HTTP errors are not
    retried since retrying will not fix them.

    Raises RuntimeError with a human-readable, actionable message on any failure.
    """
    config = config or load_config()
    prompt = prompt or DEFAULT_PROMPT
    if retries is None:
        retries = config.get("retries", DEFAULT_RETRY)
    if retries < 1:
        retries = 1

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

    last_error = None
    for attempt in range(1, retries + 1):
        try:
            return _do_request(config, payload, endpoint)
        except RuntimeError as exc:
            last_error = exc
            if not _is_retryable(str(exc)) or attempt == retries:
                raise
            wait = min(2 ** (attempt - 1), 8)
            msg = str(exc).rstrip(".")
            print(
                f"warning: Ollama request failed (attempt {attempt}/{retries}): "
                f"{msg}. Retrying in {wait}s...",
                file=sys.stderr,
            )
            time.sleep(wait)
    raise last_error  # pragma: no cover - loop always returns or raises


def _emit_json(screenshot, model, prompt, description, duration_ms):
    """Print a machine-readable JSON result object."""
    obj = {
        "screenshot": screenshot,
        "model": model,
        "prompt": prompt,
        "description": description,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "duration_ms": int(duration_ms),
    }
    print(json.dumps(obj, ensure_ascii=False))


def _parse_args(argv):
    """Split argv into (image_path, prompt, retries, json_mode, show_help)."""
    image_path = None
    prompt_parts = []
    retries = None
    json_mode = False
    show_help = False
    i = 1
    while i < len(argv):
        arg = argv[i]
        if arg in ("-h", "--help"):
            show_help = True
        elif arg == "--retry":
            if i + 1 >= len(argv):
                print("error: --retry requires a numeric argument", file=sys.stderr)
                sys.exit(2)
            try:
                retries = int(argv[i + 1])
            except ValueError:
                print(f"error: --retry expects an integer, got {argv[i + 1]!r}",
                      file=sys.stderr)
                sys.exit(2)
            i += 1
        elif arg.startswith("--retry="):
            try:
                retries = int(arg.split("=", 1)[1])
            except ValueError:
                print(f"error: --retry expects an integer, got {arg!r}",
                      file=sys.stderr)
                sys.exit(2)
        elif arg == "--json":
            json_mode = True
        elif image_path is None:
            image_path = arg
        else:
            prompt_parts.append(arg)
        i += 1
    prompt = " ".join(prompt_parts) if prompt_parts else None
    return image_path, prompt, retries, json_mode, show_help


def main(argv):
    image_path, prompt, retries, json_mode, show_help = _parse_args(argv)

    if show_help or image_path is None:
        print(__doc__.strip())
        return 0 if show_help else 2

    compare_image = os.environ.get("OPENVIST_COMPARE_IMAGE") or None
    config = load_config()
    if retries is not None:
        config["retries"] = retries

    start = time.monotonic()
    try:
        result = analyze(image_path, prompt, config=config,
                         compare_image=compare_image)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # pragma: no cover - unexpected safety net
        print(f"unexpected error: {exc}", file=sys.stderr)
        return 1
    duration_ms = (time.monotonic() - start) * 1000

    if json_mode:
        _emit_json(image_path, config["model"], prompt or DEFAULT_PROMPT,
                   result, duration_ms)
        return 0

    print(result)
    banner = os.environ.get("OPENVIST_BANNER")
    if banner:
        print(f"\n---\n_{banner}_")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
