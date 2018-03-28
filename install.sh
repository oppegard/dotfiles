#!/usr/bin/env bash
set -e

# install homebrew
if [[ ! -f /usr/local/bin/brew ]]; then
  echo "Installing homebrew"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo "brew bundling..."
brew bundle