#!/usr/bin/env bash

set -euo pipefail

mkdir -p "$HOME/.config" \
  "$HOME/.config/sublime-text/Packages" \
  "$HOME/.local/bin" \
  "$HOME/.ssh"
chmod 700 $HOME/.ssh
  
__os="$(uname -s)"
if [ "$__os" = "Darwin" ]; then
  APP_SUPPORT="$HOME/Library/Application Support"
  mkdir -p "$APP_SUPPORT/Sublime Text 3/Packages"
  ln -sf "$HOME/.config/sublime-text/Packages/User" "$APP_SUPPORT/Sublime Text 3/Packages/"
  
  mkdir -p "$APP_SUPPORT/Rectangle Pro"
fi

pkgs=(bash btop codex dig ghostty git rectangle screen shell ssh starship sublime-text tmux xdg-bin)
for pkg in "${pkgs[@]}"; do
    echo "stowing $pkg"
    stow "$pkg"
done

