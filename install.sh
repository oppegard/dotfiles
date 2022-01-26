#!/usr/bin/env zsh
set -e -o pipefail
if [[ $SHELL =~ "zsh" ]]; then
  echo "Verified running Z shell"
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

mkdir -p "${HOME}/.config"
ZDOTDIR="${ZDOTDIR:-$HOME}"
echo ZDOTDIR is "$ZDOTDIR"

SUBL_PREFS_DIR="${HOME}/Library/Application Support/Sublime Text 3/Packages/User"
mkdir -p "${SUBL_PREFS_DIR}"

declare -A files_to_link
files_to_link=(
  $ZDOTDIR/.zshenv            $DOTFILES_DIR/zshenv
  $ZDOTDIR/.zprofile          $DOTFILES_DIR/zprofile
  $ZDOTDIR/.zshrc             $DOTFILES_DIR/zshrc
  $HOME/bin                   $DOTFILES_DIR/bin
  $HOME/.ackrc                $DOTFILES_DIR/ackrc
  $HOME/.digrc                $DOTFILES_DIR/digrc
  $HOME/.gitconfig            $DOTFILES_DIR/gitconfig
  $HOME/.gitignore_global     $DOTFILES_DIR/gitignore_global
  $HOME/.screenrc             $DOTFILES_DIR/screenrc
  $HOME/.vimrc                $DOTFILES_DIR/vimrc
  $HOME/.config/starship.toml $DOTFILES_DIR/starship.toml

  "$SUBL_PREFS_DIR/Preferences.sublime-settings" "$DOTFILES_DIR/sublime/Preferences.sublime-settings"
  "$SUBL_PREFS_DIR/Git Commit.sublime-settings"  "$DOTFILES_DIR/sublime/Git Commit.sublime-settings"
)

(
set +x
# TODO: instead of skipping, have it make a backup and link anyways?
for link_name source_file in ${(kv)files_to_link}; do
  if [[ -e "$link_name" ]]; then
    echo "SKIPPING $source_file -> $link_name: already exists."
  else
    echo "LINKING $source_file -> $link_name."
    ln -sf "$source_file" "$link_name"
  fi
done
)
