#!/bin/bash
# Shared helpers for dotf and bootstrap; compatible with macOS's Bash 3.2.

# Print a timestamp using gdate (GNU coreutils) when available, otherwise
# fall back to BSD date. The first argument is the GNU format string; the
# optional second argument is the POSIX fallback format used when gdate is
# absent (defaults to the GNU format). This is the single place that decides
# whether to use gdate, so the macOS/BSD fallback lives in one spot.
dotf_date() {
    local gnu_format="$1"
    local posix_format="${2:-$gnu_format}"
    if command -v gdate &> /dev/null; then
        gdate "+$gnu_format"
    else
        date "+$posix_format"
    fi
}

debug() {
    timestamp=$(dotf_date '%H:%M:%S.%3N' '%H:%M:%S')
    local message="[$timestamp] $1"

    # Always write to log file
    echo "$message" >> "$LOG_FILE"

    # Also output to STDOUT if DEBUG=true
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "$message"
    fi
}

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
