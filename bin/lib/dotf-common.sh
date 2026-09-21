#!/bin/bash
# Shared helpers for dotf and bootstrap; compatible with macOS's Bash 3.2.

announce() {
    if command -v gum >/dev/null 2>&1; then
        gum style --bold --foreground 212 "$1"
    else
        printf '==> %s\n' "$1"
    fi
}

ensure_homebrew_env() {
    local shellenv
    if [ ! -x /opt/homebrew/bin/brew ]; then
        echo "Error: Homebrew was not found at /opt/homebrew/bin/brew." >&2
        return 1
    fi
    shellenv="$(/opt/homebrew/bin/brew shellenv bash)" || return
    eval "$shellenv"
}

ensure_mise_env() {
    export PATH="$HOME/.local/bin:$PATH"
    hash -r

    if ! command -v mise >/dev/null 2>&1; then
        echo "Error: mise was not found in ~/.local/bin or PATH." >&2
        return 1
    fi

    eval "$(mise activate bash)"
}

verify_tools() {
    /opt/homebrew/bin/brew --version
    /opt/homebrew/bin/bash --version
    mise --version
}
