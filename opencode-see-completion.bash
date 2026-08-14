# bash completion for opencode-see -------------------------------------------
#
# Source this file (or install it via install.sh) to get tab-completion for the
# opencode-see command: modes, flags, and prompt-template names.
#
# Manual install:
#   cp opencode-see-completion.bash ~/.local/share/bash-completion/completions/opencode-see
#   # or add to ~/.bashrc:  source /path/to/opencode-see-completion.bash

_opencode_see_prompts_dir() {
    local dir
    for dir in \
        "${XDG_CONFIG_HOME:-$HOME/.config}/opencode-see/../prompts" \
        "$HOME/.local/share/opencode-see/prompts" \
        "$(dirname "$(command -v opencode-see 2>/dev/null)")/prompts"; do
        if [[ -d "$dir" ]]; then
            printf '%s' "$dir"
            return 0
        fi
    done
    return 1
}

_opencode_see() {
    local cur prev
    _init_completion 2>/dev/null || {
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    }

    # Modes (positional, first non-flag argument).
    local modes="full left right region window"

    # Flags that take an argument.
    case "$prev" in
        --prompt-template)
            local pdir names
            if pdir="$(_opencode_see_prompts_dir)"; then
                names="$(cd "$pdir" 2>/dev/null && find . -maxdepth 1 -name '*.txt' \
                    -printf '%f\n' 2>/dev/null | sed 's/\.txt$//' | tr '\n' ' ')"
                mapfile -t COMPREPLY < <(compgen -W "$names" -- "$cur")
            fi
            return 0
            ;;
        --compare|--output)
            mapfile -t COMPREPLY < <(compgen -f -- "$cur")
            return 0
            ;;
        --retry)
            mapfile -t COMPREPLY < <(compgen -W "1 2 3 4 5" -- "$cur")
            return 0
            ;;
        --history)
            mapfile -t COMPREPLY < <(compgen -W "5 10 20 50" -- "$cur")
            return 0
            ;;
    esac

    # Suggest flags or modes depending on context.
    if [[ "$cur" == -* ]]; then
        local flags="--prompt-template --annotate --compare --output --json --quiet --dry-run --retry --history --list-models --check --verbose --version --help"
        mapfile -t COMPREPLY < <(compgen -W "$flags" -- "$cur")
        return 0
    fi

    # If no mode has been given yet, suggest modes.
    local have_mode=0 w
    for w in "${COMP_WORDS[@]:1}"; do
        case "$w" in
            full|left|right|region|window) have_mode=1; break ;;
            -*) continue ;;
            *) have_mode=1; break ;;
        esac
    done
    if [[ "$have_mode" -eq 0 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$modes" -- "$cur")
        return 0
    fi

    # Default: complete with remaining flags.
    local flags="--prompt-template --annotate --compare --output --json --quiet --dry-run --retry --history --verbose"
    mapfile -t COMPREPLY < <(compgen -W "$flags" -- "$cur")
    return 0
}

complete -F _opencode_see opencode-see
