#!/usr/bin/env bash

set -euo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [ -L "$SOURCE_PATH" ]; do
    SOURCE_DIR="$(cd -P "$(dirname "$SOURCE_PATH")" && pwd)"
    SOURCE_PATH="$(readlink "$SOURCE_PATH")"
    case "$SOURCE_PATH" in
        /*) ;;
        *) SOURCE_PATH="$SOURCE_DIR/$SOURCE_PATH" ;;
    esac
done

SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE_PATH")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
export DOTFILES_DIR

export_betterdisplay_preferences() {
  [ -d "/Applications/BetterDisplay.app" ] || return 0

  local preferences_path temporary_path
  preferences_path="$DOTFILES_DIR/mise-dots/macos/BetterDisplay.plist"
  temporary_path="$(mktemp "${TMPDIR:-/tmp}/betterdisplay-preferences.XXXXXX")"

  if ! defaults export pro.betterdisplay.BetterDisplay "$temporary_path"; then
    rm -f "$temporary_path"
    return 1
  fi

  if ! plutil -convert xml1 "$temporary_path"; then
    rm -f "$temporary_path"
    return 1
  fi

  if [ ! -f "$preferences_path" ] || ! cmp -s "$temporary_path" "$preferences_path"; then
    mv "$temporary_path" "$preferences_path"
    echo "INFO: BetterDisplay preferences changed; commit mise-dots/macos/BetterDisplay.plist"
  else
    rm -f "$temporary_path"
  fi
}

mkdir -p \
  "$HOME/.config" \
  "$HOME/.local/bin" \
  "$HOME/.claude" \
  "$HOME/.codex" \
  "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
  
__os="$(uname -s)"
### Mac Setup ###
if [ "$__os" = "Darwin" ]; then
  BREWFILE="$DOTFILES_DIR/Brewfile"
  brew bundle install --file="$BREWFILE"

   brew cleanup
   # If lots of warnings, run `brew upgrade`

  export_betterdisplay_preferences
fi

STOW_DIR="$DOTFILES_DIR/stow"
if [ ! -f "$STOW_DIR/.stowrc" ]; then
  echo "ERROR: $STOW_DIR/.stowrc not found" >&2
  exit 1
fi

cd "$STOW_DIR"
stow_pkgs=(
  codex
)
for stow_pkg in "${stow_pkgs[@]}"; do
    echo "stowing $stow_pkg"
    stow "$stow_pkg"
done

cd "$DOTFILES_DIR/mise"
mise bootstrap

DOTFILES_WORK_DIR="${DOTFILES_DIR}-work"
if [ -d "$DOTFILES_WORK_DIR" ]; then
  echo
  echo "Running $DOTFILES_WORK_DIR/bin/setup.sh:"
  "$DOTFILES_WORK_DIR/bin/setup.sh"
fi
