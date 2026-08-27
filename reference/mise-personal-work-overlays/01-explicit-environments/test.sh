#!/usr/bin/env bash

set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d)"
fixture="$test_root/fixture"
test_home="$test_root/home"

trap 'rm -rf "$test_root"' EXIT
cp -R "$source_dir" "$fixture"
mkdir -p "$test_home"

export HOME="$test_home"
export XDG_CACHE_HOME="$test_home/.cache"
export XDG_CONFIG_HOME="$test_home/.config"
export XDG_DATA_HOME="$test_home/.local/share"
export XDG_STATE_HOME="$test_home/.local/state"
(cd "$test_root" && mise trust "$fixture/mise.toml")
(cd "$test_root" && mise trust "$fixture/mise.work.toml")

mise -C "$fixture" bootstrap dotfiles apply --yes
grep -q 'personal@example.test' "$HOME/.config/git/identity"
test "$(git config --file "$HOME/.gitconfig" --includes --get user.email)" = \
  "personal@example.test"
grep -q 'src/personal' "$HOME/.codex/config.toml"
CODEX_HOME="$HOME/.codex" codex features list >/dev/null

mise -C "$fixture" -E work bootstrap dotfiles apply --yes
grep -q 'work@example.test' "$HOME/.config/git/identity"
test "$(git config --file "$HOME/.gitconfig" --includes --get user.email)" = \
  "work@example.test"
grep -q 'company-docs' "$HOME/.codex/config.toml"
CODEX_HOME="$HOME/.codex" codex features list >/dev/null

mise -C "$fixture" -E work bootstrap dotfiles apply --yes
mise -C "$fixture" -E work bootstrap dotfiles status --missing
