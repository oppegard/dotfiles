#!/usr/bin/env bash

# Post-packages hook for `mise bootstrap` (see [bootstrap.hooks] in
# mise/config.toml).

ensure_git_version() {
  local required=2.54.0
  local script_dir semver_path git_path git_output installed comparison

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || return 1
  semver_path="$script_dir/../../vendor/semver"
  if [[ ! -x $semver_path ]]; then
    printf 'Git version check requires %s.\n' "$semver_path" >&2
    return 1
  fi

  git_path="$(command -v git)" || {
    printf 'Git %s or newer is required, but git is not on PATH.\n' "$required" >&2
    return 1
  }

  git_output="$("$git_path" --version)" || {
    printf 'Could not determine the Git version from %s.\n' "$git_path" >&2
    return 1
  }

  if [[ $git_output =~ ^git[[:space:]]version[[:space:]]([^[:space:]]+) ]]; then
    installed="${BASH_REMATCH[1]}"
  else
    printf 'Could not parse the Git version from %s: %s\n' "$git_path" "$git_output" >&2
    return 1
  fi

  comparison="$("$semver_path" compare "$installed" "$required")" || {
    printf 'Could not compare Git version %s with %s.\n' "$installed" "$required" >&2
    return 1
  }

  case "$comparison" in
  -1)
    printf 'Git %s or newer is required; found %s at %s.\n' "$required" "$git_output" "$git_path" >&2
    return 1
    ;;
  0 | 1) return 0 ;;
  *)
    printf 'Unexpected semver comparison result: %s\n' "$comparison" >&2
    return 1
    ;;
  esac
}

ensure_git_version
