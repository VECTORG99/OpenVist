#!/usr/bin/env bats
#
# Tests for the opencode-see bash script.
#

load test_helper

@test "opencode-see has valid bash syntax" {
    bash -n "$SEE_SCRIPT"
}

@test "opencode-see --version prints a version" {
    run "$SEE_SCRIPT" --version
    [ "$status" -eq 0 ]
    [[ "$output" == opencode-see* ]]
}

@test "opencode-see --help prints usage and exits 0" {
    run "$SEE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--check"* ]]
    [[ "$output" == *"--version"* ]]
}

@test "opencode-see -h is an alias for --help" {
    run "$SEE_SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "opencode-see --check runs and reports results" {
    run "$SEE_SCRIPT" --check
    # --check should always print the header; exit code depends on environment.
    [[ "$output" == *"OpenVist health check"* ]]
}

@test "opencode-see rejects an unknown mode" {
    run "$SEE_SCRIPT" notarealmode
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown mode"* ]]
}

@test "opencode-see left mode errors when LEFT_MON unset" {
    run env -u LEFT_MON "$SEE_SCRIPT" left
    [ "$status" -ne 0 ]
    [[ "$output" == *"LEFT_MON"* ]]
}

@test "opencode-see right mode errors when RIGHT_MON unset" {
    run env -u RIGHT_MON "$SEE_SCRIPT" right
    [ "$status" -ne 0 ]
    [[ "$output" == *"RIGHT_MON"* ]]
}
