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

git -C "$DOTFILES_DIR" pull

# Required before the first heading; setup may run from a shell without mise activation.
mise -C "$DOTFILES_DIR/mise" install gum

gum_print() {
  mise -C "$DOTFILES_DIR/mise" exec gum -- gum style --foreground 212 \
    --border-foreground 212 --border double --align center \
    --margin "1 0" --padding "1 2" --bold --width 72 "$@"
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
  gum_print "☕️ ☕️ ☕️  BREWING  ☕️ ☕️ ☕️"

  BREWFILE="$DOTFILES_DIR/Brewfile"
  brew bundle install --file="$BREWFILE"

   brew cleanup
   # If lots of warnings, run `brew upgrade`

  mise run -C "$DOTFILES_DIR/mise" betterdisplay:export
fi

gum_print "📦 📦 📦  STOWING  📦 📦 📦"
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

gum_print "👨‍🍳 👨‍🍳 👨‍🍳  MISE BOOTSTRAP  👨‍🍳 👨‍🍳 👨‍🍳"
mise -C "$DOTFILES_DIR/mise" bootstrap

gum_print "⬆️ ⬆️ ⬆️  MISE UPGRADE  ⬆️ ⬆️ ⬆️"
mise -C "$DOTFILES_DIR/mise" upgrade

gum_print "💼 💼 💼  STOWING WORK  💼 💼 💼"
DOTFILES_WORK_DIR="${DOTFILES_DIR}-work"
if [ -d "$DOTFILES_WORK_DIR" ]; then
  echo
  echo "Running $DOTFILES_WORK_DIR/bin/setup.sh:"
  "$DOTFILES_WORK_DIR/bin/setup.sh"
fi
