#!/usr/bin/env bash
#
# Common helpers for OpenVist bats tests.
#
# Source this from your *.bats files with:
#   load test_helper
#

# Absolute path to the project root (the repo directory).
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export PROJECT_ROOT

# The main script under test.
SEE_SCRIPT="$PROJECT_ROOT/opencode-see"
export SEE_SCRIPT

# The Python helper under test.
VISION_PY="$PROJECT_ROOT/vision_analyze.py"
export VISION_PY

# Create a tiny valid PNG (1x1) for tests that need an image file.
make_test_image() {
    local out="${1:-$BATS_TMPDIR/test.png}"
    # 1x1 red PNG (base64-encoded).
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf\xc0\x00\x00\x00\x03\x00\x01\x00\x05\xfe\xd4\x00\x00\x00\x00IEND\xaeB`\x82' > "$out"
    echo "$out"
}
export -f make_test_image
