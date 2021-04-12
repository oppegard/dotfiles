#!/usr/bin/env bash
set -e -o pipefail
if [[ $SHELL =~ "zsh" ]]; then
  echo "Verified running zsh shell"
else
  echo Unsupported shell $SHELL
  exit 1
fi

DOTFILES_DIR="$(pwd)"
if [[ $(basename "$DOTFILES_DIR") != "dotfiles" ]]; then
  echo "Script doesn't appear to have been invoked from the dotfiles directory."
  echo "Currently in $(pwd). Exiting."
  exit 1
fi

echo Setting up zsh
ZDOTDIR="${ZDOTDIR:-$HOME}"
echo ZDOTDIR is "$ZDOTDIR"
(
  set -x
  ln -sf "$DOTFILES_DIR"/zshenv "$ZDOTDIR"/.zshenv
  ln -sf "$DOTFILES_DIR"/zprofile "$ZDOTDIR"/.zprofile
  ln -sf "$DOTFILES_DIR"/zshrc "$ZDOTDIR"/.zshrc
)

echo Setting up misc
(
  set -x
  # if ~/bin symlink is already set up, this will create another symlink at ~/bin/bin :(
  if [[ -e "$HOME/bin" ]]; then
    echo "SKIPPING symlink of HOME/bin as it already exists."
  else
    ln -sf "$DOTFILES_DIR/bin" "$HOME/bin"
  fi
)

echo Setting up starship
mkdir -p "${HOME}/.config"
ln -sf "$DOTFILES_DIR/starship.toml" "${HOME}/.config/starship.toml"

echo Setting up ack
mkdir -p "${HOME}/.config"
ln -sf "$DOTFILES_DIR/ackrc" "${HOME}/.ackrc"
