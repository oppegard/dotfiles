#!/usr/bin/env bash

set -euo pipefail

mkdir -p "$HOME/.config" \
  "$HOME/.config/sublime-text/Packages" \
  "$HOME/.local/bin" \
  "$HOME/.claude" \
  "$HOME/.codex" \
  "$HOME/.ssh"
chmod 700 $HOME/.ssh
  
__os="$(uname -s)"
### Mac Setup ###
if [ "$__os" = "Darwin" ]; then
  APP_SUPPORT="$HOME/Library/Application Support"
  mkdir -p "$APP_SUPPORT/Sublime Text 3/Packages"
  ln -sf "$HOME/.config/sublime-text/Packages/User" "$APP_SUPPORT/Sublime Text 3/Packages/"
  
  mkdir -p "$APP_SUPPORT/Rectangle Pro"

  brew_pkgs=(bash btop cleanshot codex ghostty git gitleaks hazeover mise rectangle-pro screen starship tmux)
  for brew_pkg in "${brew_pkgs[@]}"; do
      echo "brewing $brew_pkg"
      brew install "$brew_pkg" || true
  done

fi

stow_pkgs=(bash btop claude-code codex dig ghostty git rectangle screen shell ssh starship sublime-text tmux xdg-bin)
for stow_pkg in "${stow_pkgs[@]}"; do
    echo "stowing $stow_pkg"
    stow "$stow_pkg"
done

