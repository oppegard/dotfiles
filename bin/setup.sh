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
MISE_CONFIG_DIR="$DOTFILES_DIR/files/home/.config/mise"
# shellcheck source=bin/lib/dotf-common.sh
source "$SCRIPT_DIR/lib/dotf-common.sh"

ensure_mise_env

git -C "$DOTFILES_DIR" push
git -C "$DOTFILES_DIR" pull

# Required before the first heading; setup may run from a shell without mise activation.
mise -C "$MISE_CONFIG_DIR" install gum

resolve_mise_env() {
  local mise_env="${MISE_ENV:-}"

  if [[ -z "$mise_env" ]]; then
    mise_env="$(
      mise -C "$MISE_CONFIG_DIR" exec -- printenv MISE_ENV 2>/dev/null || :
    )"
  fi

  if [[ -z "$mise_env" ]]; then
    if [[ ! -t 0 ]]; then
      echo "ERROR: set MISE_ENV=home or MISE_ENV=work when running non-interactively." >&2
      return 1
    fi

    if ! mise_env="$(
      mise -C "$MISE_CONFIG_DIR" exec gum -- \
        gum choose --header "Select the mise environment:" home work
    )"; then
      echo "ERROR: mise environment selection was cancelled." >&2
      return 1
    fi
  fi

  if [[ ! "$mise_env" =~ ^(home|work)$ ]]; then
    echo "ERROR: MISE_ENV must be home or work." >&2
    return 1
  fi

  printf '%s\n' "$mise_env"
}

MISE_ENV="$(resolve_mise_env)"
export MISE_ENV

gum_print() {
  mise -C "$MISE_CONFIG_DIR" exec gum -- gum style --foreground 212 \
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

gum_print "👨‍🍳 👨‍🍳 👨‍🍳  MISE BOOTSTRAP  👨‍🍳 👨‍🍳 👨‍🍳"
mise -C "$MISE_CONFIG_DIR" bootstrap
mise -C "$MISE_CONFIG_DIR" bootstrap packages upgrade

gum_print "⬆️ ⬆️ ⬆️  MISE UPGRADE  ⬆️ ⬆️ ⬆️"
mise -C "$MISE_CONFIG_DIR" upgrade

__os="$(uname -s)"

### Mac Setup ###
if [ "$__os" = "Darwin" ]; then
  gum_print "☕️ ☕️ ☕️  BREWING  ☕️ ☕️ ☕️"

  brew bundle install --file="$DOTFILES_DIR/Brewfile"
  brew cleanup # If lots of warnings, run `brew upgrade`

  gum_print "🍎️ 🍎️ 🍎️  MISE Mac Tasks  🍎️ 🍎️ 🍎️"
  mise run -C "$MISE_CONFIG_DIR" betterdisplay:export

  # Make sure programs that are installed are run, so that I can configure them to open at login
  open -g -a BetterDisplay
  open -g -a Clocker
  open -g -a SoundSource
fi
