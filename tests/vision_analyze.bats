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
    # We cannot reach a real Ollama in CI, but we can verify the script gets
    # past argument parsing and image loading, then fails on the network call
    # with a clear "cannot reach Ollama" message.
    local img
    img="$(make_test_image)"
    run python3 "$VISION_PY" "$img" "describe this"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Ollama"* ]]
    rm -f "$img"
}
