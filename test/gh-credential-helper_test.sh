#!/usr/bin/env bash

set -euo pipefail

repository_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repository_directory/bin/check-gh-credential-helper"
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/gh-credential-helper-test.XXXXXX")"

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

stub_directory="$temporary_directory/bin"
global_gitconfig="$temporary_directory/gitconfig"
mkdir -p "$stub_directory"

# Match the literal value stored in Git configuration.
# shellcheck disable=SC2016
expected_helper='!MISE_EXEC_AUTO_INSTALL=0 $HOME/.local/bin/mise exec --quiet gh -- gh auth git-credential'
for host in github.com gist.github.com; do
  git config --file "$global_gitconfig" --add "credential.https://$host.helper" ""
  git config --file "$global_gitconfig" --add "credential.https://$host.helper" "$expected_helper"
done

cat >"$stub_directory/gh" <<'EOF'
#!/bin/sh
set -eu

if [ "$#" -eq 1 ] && [ "$1" = "--version" ]; then
  printf '%s\n' 'gh version 2.101.0 (test)'
  exit 0
fi

printf 'unexpected gh arguments: %s\n' "$*" >&2
exit 64
EOF
chmod +x "$stub_directory/gh"

cat >"$stub_directory/mise" <<'EOF'
#!/bin/sh
set -eu

if [ "$#" -eq 6 ] &&
  [ "$1" = "exec" ] &&
  [ "$2" = "--quiet" ] &&
  [ "$3" = "gh" ] &&
  [ "$4" = "--" ] &&
  [ "$5" = "gh" ] &&
  [ "$6" = "--version" ]; then
  printf '%s\n' 'gh version 2.101.0 (test)'
  exit 0
fi

printf 'unexpected mise arguments: %s\n' "$*" >&2
exit 64
EOF
chmod +x "$stub_directory/mise"

GIT_CONFIG_GLOBAL="$global_gitconfig" \
  MISE_BIN="$stub_directory/mise" \
  PATH="$stub_directory:/usr/bin:/bin" \
  "$checker" >/dev/null 2>&1

git config --file "$global_gitconfig" --unset-all \
  credential.https://github.com.helper

set +e
missing_helper_output="$({
  GIT_CONFIG_GLOBAL="$global_gitconfig" \
    MISE_BIN="$stub_directory/mise" \
    PATH="$stub_directory:/usr/bin:/bin" \
    "$checker"
} 2>&1)"
missing_helper_exit=$?
set -e

if [ "$missing_helper_exit" -eq 0 ] ||
  [[ "$missing_helper_output" == *"bad array subscript"* ]]; then
  echo "expected a missing helper to produce a controlled rejection" >&2
  exit 1
fi

git config --file "$global_gitconfig" --add \
  credential.https://github.com.helper ""
git config --file "$global_gitconfig" --add \
  credential.https://github.com.helper "$expected_helper"

git config --file "$global_gitconfig" --replace-all \
  credential.https://github.com.helper \
  '!/Users/test/.local/share/mise/installs/gh/2/gh_2.102.0_macOS_arm64/bin/gh auth git-credential'

set +e
GIT_CONFIG_GLOBAL="$global_gitconfig" \
  MISE_BIN="$stub_directory/mise" \
  PATH="$stub_directory:/usr/bin:/bin" \
  "$checker" >/dev/null 2>&1
pinned_helper_exit=$?
set -e

if [ "$pinned_helper_exit" -eq 0 ]; then
  echo "expected a version-pinned GitHub helper to be rejected" >&2
  exit 1
fi

git config --file "$global_gitconfig" --replace-all \
  credential.https://github.com.helper \
  "$expected_helper"

cat >"$stub_directory/mise" <<'EOF'
#!/bin/sh
set -eu

if [ "$#" -eq 6 ] &&
  [ "$1" = "exec" ] &&
  [ "$2" = "--quiet" ] &&
  [ "$3" = "gh" ] &&
  [ "$4" = "--" ] &&
  [ "$5" = "gh" ] &&
  [ "$6" = "--version" ]; then
  printf '%s\n' 'gh version 2.102.0 (test)'
  exit 0
fi

printf 'unexpected mise arguments: %s\n' "$*" >&2
exit 64
EOF
chmod +x "$stub_directory/mise"

set +e
GIT_CONFIG_GLOBAL="$global_gitconfig" \
  MISE_BIN="$stub_directory/mise" \
  PATH="$stub_directory:/usr/bin:/bin" \
  "$checker" >/dev/null 2>&1
resolver_mismatch_exit=$?
set -e

if [ "$resolver_mismatch_exit" -eq 0 ]; then
  echo "expected a resolver-version mismatch to be rejected" >&2
  exit 1
fi
