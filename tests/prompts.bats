#!/usr/bin/env bats
#
# Tests for the prompt templates feature.
#

load test_helper

@test "prompts directory exists" {
    [ -d "$PROMPTS_DIR" ]
}

@test "all expected prompt templates are present" {
    local templates=(default errors code debug ui)
    local t
    for t in "${templates[@]}"; do
        [ -f "$PROMPTS_DIR/$t.txt" ]
    done
}

@test "default.txt contains a description prompt" {
    run cat "$PROMPTS_DIR/default.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Describe"* ]]
}

@test "errors.txt focuses on errors and warnings" {
    run cat "$PROMPTS_DIR/errors.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"errors"* ]]
    [[ "$output" == *"warnings"* ]]
}

@test "code.txt mentions code editor or terminal" {
    run cat "$PROMPTS_DIR/code.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"code"* ]]
}

@test "debug.txt mentions debugging" {
    run cat "$PROMPTS_DIR/debug.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"debugging"* ]]
}

@test "ui.txt mentions UI layout" {
    run cat "$PROMPTS_DIR/ui.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UI"* ]]
}

@test "prompt templates are non-empty" {
    local templates=(default errors code debug ui)
    local t content
    for t in "${templates[@]}"; do
        content="$(cat "$PROMPTS_DIR/$t.txt")"
        [ -n "$content" ]
    done
}
