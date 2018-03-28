#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(pwd)"

###############################################################################
# Homebrew / Cask                                                             #
###############################################################################

if [[ ! -f /usr/local/bin/brew ]]; then
  echo "Installing homebrew"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo "brew bundling..."
brew bundle


###############################################################################
# Nix                                                                         #
###############################################################################
if [[ ! -f ~/.bash_it ]]; then
  git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it
fi

ln -sf "${DOTFILES_DIR}/bash_profile" ~/.bash_profile

###############################################################################
# Spectacle.app                                                               #
###############################################################################
mkdir -p ~/Library/Application\ Support/Spectacle/
ln -sf "${DOTFILES_DIR}/spectacle.json" ~/Library/Application\ Support/Spectacle/Shortcuts.json