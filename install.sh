#!/usr/bin/env zsh
set -e -o pipefail
if [[ $SHELL =~ "zsh" ]]; then
  echo "Verified running Z shell"
else
  echo "ERROR: Unsupported shell $SHELL"
  exit 1
fi

# Run this script from ~/src/dotfiles/, which is a symlink to ~/Dropbox/dotfiles
DOTFILES_DIR="$(pwd)"
if [[ $(basename "$DOTFILES_DIR") != "dotfiles" ]]; then
  echo "ERROR: Script doesn't appear to have been invoked from the dotfiles directory."
  echo "ERROR: Currently in $(pwd). Exiting."
  exit 1
fi

mkdir -p "${HOME}/.config"
ZDOTDIR="${ZDOTDIR:-$HOME}"
echo ZDOTDIR is "$ZDOTDIR"

declare -A files_to_link
files_to_link=(
  $ZDOTDIR/.zshenv              $DOTFILES_DIR/zshenv
  $ZDOTDIR/.zprofile            $DOTFILES_DIR/zprofile
  $ZDOTDIR/.zshrc               $DOTFILES_DIR/zshrc
  $HOME/bin                     $DOTFILES_DIR/bin
  $HOME/.ackrc                  $DOTFILES_DIR/ackrc
  $HOME/.tmux.conf              $DOTFILES_DIR/tmux.conf
  $HOME/.vimrc                  $DOTFILES_DIR/vimrc
  $HOME/.config/direnv/direnvrc $DOTFILES_DIR/direnvrc
  $HOME/.asdf                   $HOME/.local/share/mise
)

(
set +x
# TODO: instead of skipping, have it make a backup and link anyways?
for link_name source_file in ${(kv)files_to_link}; do
  if [[ -e "$link_name" ]]; then
    echo "Skipping $source_file -> $link_name: already exists."
  else
    echo "LINKING $source_file -> $link_name."
    ln -sf "$source_file" "$link_name"
  fi
done
)

### iTerm ###
# Specify the preferences directory
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$HOME/src/dotfiles"
# Tell iTerm2 to use the custom preferences in the directory
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
