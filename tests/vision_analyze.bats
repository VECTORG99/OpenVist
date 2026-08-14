#!/usr/bin/env bats
#
# Tests for the vision_analyze.py helper script.
#

load test_helper

@test "vision_analyze.py compiles" {
    run python3 -m py_compile "$VISION_PY"
    [ "$status" -eq 0 ]
}

@test "vision_analyze.py --help prints usage" {
    run python3 "$VISION_PY" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "vision_analyze.py with no args exits non-zero" {
    run python3 "$VISION_PY"
    [ "$status" -ne 0 ]
}

@test "vision_analyze.py errors on missing image file" {
    run python3 "$VISION_PY" "/nonexistent/path/to/image.png" "describe"
    [ "$status" -ne 0 ]
    [[ "$output" == *"image file not found"* ]]
}

@test "vision_analyze.py accepts an image path and prompt argument" {
    # Point Ollama at an unreachable port so the script always fails on the
    # network call with a clear "cannot reach Ollama" message, regardless of
    # whether a real Ollama is running on the host.
    local img
    img="$(make_test_image)"
    run env OLLAMA_URL="http://127.0.0.1:1" python3 "$VISION_PY" "$img" "describe this"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Ollama"* ]]
    rm -f "$img"
}

@test "vision_analyze.py comparison mode loads both images before failing" {
    local img1 img2
    img1="$(make_test_image "$BATS_TMPDIR/cmp1.png")"
    img2="$(make_test_image "$BATS_TMPDIR/cmp2.png")"
    run env OLLAMA_URL="http://127.0.0.1:1" OPENVIST_COMPARE_IMAGE="$img2" \
        python3 "$VISION_PY" "$img1" "what changed"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Ollama"* ]]
    rm -f "$img1" "$img2"
}

@test "vision_analyze.py comparison mode errors on missing second image" {
    local img
    img="$(make_test_image)"
    run env OPENVIST_COMPARE_IMAGE="/nonexistent/second.png" python3 "$VISION_PY" "$img" "compare"
    [ "$status" -ne 0 ]
    [[ "$output" == *"image file not found"* ]]
    rm -f "$img"
}

@test "vision_analyze.py banner is not printed when OPENVIST_BANNER unset" {
    # Confirm the env var path does not crash with a traceback; the script
    # fails on the unreachable Ollama before printing any banner.
    local img
    img="$(make_test_image)"
    run env -u OPENVIST_BANNER OLLAMA_URL="http://127.0.0.1:1" \
        python3 "$VISION_PY" "$img" "describe"
    [ "$status" -ne 0 ]
    rm -f "$img"
}
