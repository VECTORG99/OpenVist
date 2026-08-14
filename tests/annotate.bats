#!/usr/bin/env bats
#
# Tests for the screenshot annotation feature (--annotate).
#
# These tests exercise the annotate_image function from opencode-see by
# sourcing the relevant functions directly, since a full run requires a
# Wayland session.
#

load test_helper

# Source the helper functions from opencode-see without running the main body.
_setup_funcs() {
    # shellcheck source=/dev/null
    eval "$(sed -n '
        /^log()/,/^# --- argument parsing/ {
            /^# --- argument parsing/!p
        }
    ' "$SEE_SCRIPT")"
}

@test "annotate_image creates an annotated image with caption bar" {
    if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
        skip "ImageMagick not installed"
    fi
    _setup_funcs
    OPENVIST_LOG_FILE="$BATS_TMPDIR/ann-test.log"
    VERBOSE=0
    local img annotated
    img="$BATS_TMPDIR/source.jpg"
    magick -size 120x80 xc:blue "$img" 2>/dev/null || skip "magick failed to create test image"
    annotated="$(annotate_image "$img" "Test description for annotation feature")"
    [ -f "$annotated" ]
    # The annotated image should be taller than the original (caption bar added).
    local h_orig h_ann
    h_orig="$(magick identify -format '%h' "$img" 2>/dev/null)"
    h_ann="$(magick identify -format '%h' "$annotated" 2>/dev/null)"
    [ "$h_ann" -gt "$h_orig" ]
    rm -f "$img" "$annotated"
}

@test "annotate_image output path has -annotated suffix" {
    if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
        skip "ImageMagick not installed"
    fi
    _setup_funcs
    OPENVIST_LOG_FILE="$BATS_TMPDIR/ann-test.log"
    VERBOSE=0
    local img annotated
    img="$BATS_TMPDIR/myshot.jpg"
    magick -size 60x60 xc:green "$img" 2>/dev/null || skip "magick failed to create test image"
    annotated="$(annotate_image "$img" "short desc")"
    [[ "$annotated" == *"-annotated.jpg" ]]
    [ -f "$annotated" ]
    rm -f "$img" "$annotated"
}
