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

mkdir -p \
  "$HOME/.config" \
  "$HOME/.config/sublime-text/Packages" \
  "$HOME/.local/bin" \
  "$HOME/.claude" \
  "$HOME/.codex" \
  "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
  
__os="$(uname -s)"
### Mac Setup ###
if [ "$__os" = "Darwin" ]; then
  APP_SUPPORT="$HOME/Library/Application Support"
  mkdir -p "$APP_SUPPORT/Sublime Text 3/Packages"
  ln -sf "$HOME/.config/sublime-text/Packages/User" "$APP_SUPPORT/Sublime Text 3/Packages/"
  
  mkdir -p "$APP_SUPPORT/Rectangle Pro"

  BREWFILE="$DOTFILES_DIR/Brewfile"
  brew bundle check --file="$BREWFILE" || brew bundle install --file="$BREWFILE"

  # Running below will remove mise-brewed items, manual brews, etc
  # brew bundle cleanup --file="$BREWFILE"
fi

STOW_DIR="$DOTFILES_DIR/stow"
if [ ! -f "$STOW_DIR/.stowrc" ]; then
  echo "ERROR: $STOW_DIR/.stowrc not found" >&2
  exit 1
fi

cd "$STOW_DIR"
stow_pkgs=(
  bash
  btop
  bun
  codex
  curl
  dig
  ghostty
  git
  linearmouse
  npm
  rectangle
  ripgrep
  screen
  shell
  ssh
  starship
  sublime-text
  tmux
  uv
  xdg-bin
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
