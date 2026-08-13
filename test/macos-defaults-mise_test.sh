#!/usr/bin/env bash

set -euo pipefail

repository_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_diff_script_checksum="6c06decd82f83356a6bce6f7b84c1f9c5fe6c782e22e8c745069908587b65dfc"
actual_diff_script_checksum="$(shasum -a 256 "$repository_directory/vendor/macos-defaults/diff.sh" | awk '{print $1}')"

if [ "$actual_diff_script_checksum" != "$expected_diff_script_checksum" ]; then
  echo "vendored diff.sh does not match its pinned upstream checksum" >&2
  exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "SKIP: macOS only"
  exit 0
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/mise-macos-defaults-test.XXXXXX")"
cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

cp "$repository_directory/test/fixtures/macos-defaults-mise/mise.toml" \
  "$temporary_directory/mise.toml"

mise_for_test() {
  MISE_CACHE_DIR="$temporary_directory/cache" \
    MISE_CONFIG_DIR="$temporary_directory/config" \
    MISE_DATA_DIR="$temporary_directory/data" \
    MISE_STATE_DIR="$temporary_directory/state" \
    MISE_TRUSTED_CONFIG_PATHS="$temporary_directory" \
    mise -C "$temporary_directory" "$@"
}

set +e
status_output="$(mise_for_test bootstrap macos defaults status --missing 2>&1)"
status_exit=$?
set -e

if [ "$status_exit" -eq 0 ]; then
  echo "expected status --missing to report the deliberately unset default" >&2
  exit 1
fi

if ! printf '%s\n' "$status_output" | rg -F 'com.example.dotfiles-mise-test'; then
  echo "status did not report the deliberately unset default" >&2
  exit 1
fi

dry_run_output="$(mise_for_test bootstrap macos defaults apply --dry-run --yes 2>&1)"
if ! printf '%s\n' "$dry_run_output" | rg -F 'defaults write com.example.dotfiles-mise-test boolean -bool true'; then
  echo "dry run did not print the expected typed defaults write" >&2
  exit 1
fi

if printf '%s\n' "$dry_run_output" | rg -i 'killall|restart|log out'; then
  echo "dry run must not restart applications or sessions" >&2
  exit 1
fi
