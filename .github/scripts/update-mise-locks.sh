#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/global" "$TEMP_DIR/system"

# File overrides bypass directory discovery and its environment overlays.
unset MISE_GLOBAL_CONFIG_FILE MISE_CONFIG_FILE MISE_GLOBAL_CONFIG_ROOT MISE_SYSTEM_CONFIG_FILE
unset MISE_OVERRIDE_CONFIG_FILENAMES MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES
export MISE_SYSTEM_CONFIG_DIR="$TEMP_DIR/system"
MISE_CEILING_PATHS="$(dirname "$REPO_DIR")"
export MISE_CEILING_PATHS
export MISE_AUTO_ENV=false
export MISE_ENV=home
export MISE_SAFE=1
export MISE_LOCKFILE_AUTO_PRUNE=false

planner="$REPO_DIR/.github/scripts/mise_lock_plan.rb"

config_age() {
  local file=$1
  local value
  value="$(mise config get settings.minimum_release_age --file "$file")" || exit 1
  value="${value//[[:space:]]/}"
  if [[ -z "$value" ]]; then
    echo "updater requires minimum_release_age in $file" >&2
    exit 2
  fi
  printf '%s\n' "$value"
}

mise_lock() {
  local config_dir=$1
  local global_flag=$2
  local release_age=$3
  shift 3
  if [[ "$global_flag" == --global ]]; then
    MISE_CONFIG_DIR="$config_dir" MISE_MINIMUM_RELEASE_AGE="$release_age" mise lock --global "$@"
  else
    MISE_CONFIG_DIR="$config_dir" MISE_MINIMUM_RELEASE_AGE="$release_age" mise lock "$@"
  fi
}

detect_scope() {
  local scope=$1
  local config_dir=$2
  local global_flag=$3
  local release_age=$4
  local aged="$TEMP_DIR/$scope-aged.json"
  local fresh="$TEMP_DIR/$scope-fresh.json"
  local plan="$TEMP_DIR/$scope-plan.json"
  local writes="$TEMP_DIR/$scope-writes.txt"

  mise_lock "$config_dir" "$global_flag" "$release_age" --bump --dry-run --json >"$aged"
  mise_lock "$config_dir" "$global_flag" "$release_age" --bump --dry-run --json --minimum-release-age 0s >"$fresh"
  mise exec ruby -- ruby "$planner" plan \
    --scope "$scope" \
    --aged "$aged" \
    --fresh "$fresh" \
    --out "$plan" >"$writes"
}

apply_scope() {
  local scope=$1
  local config_dir=$2
  local global_flag=$3
  local release_age=$4
  local writes="$TEMP_DIR/$scope-writes.txt"
  local tool

  if [[ "${MISE_LOCK_DRY_RUN:-}" == 1 ]]; then
    return
  fi
  while IFS= read -r tool; do
    [[ -n "$tool" ]] || continue
    if [[ ! "$tool" =~ ^[A-Za-z0-9._:@/-]+$ ]]; then
      echo "updater refused tool name" >&2
      exit 2
    fi
    mise_lock "$config_dir" "$global_flag" "$release_age" --bump --json "$tool"
  done <"$writes"
}

cd "$REPO_DIR"
project_age="$(config_age "$REPO_DIR/mise.toml")" || exit
global_age="$(config_age "$REPO_DIR/files/home/.config/mise/config.toml")" || exit
detect_scope project "$TEMP_DIR/global" "" "$project_age"
detect_scope global "$REPO_DIR/files/home/.config/mise" --global "$global_age"
apply_scope project "$TEMP_DIR/global" "" "$project_age"
apply_scope global "$REPO_DIR/files/home/.config/mise" --global "$global_age"

if [[ "$project_age" == "$global_age" ]]; then
  report_age=$project_age
else
  report_age="project $project_age, global $global_age"
fi

title_file="${MISE_LOCK_PR_TITLE_FILE:-$TEMP_DIR/title.txt}"
body_file="${MISE_LOCK_PR_BODY_FILE:-$TEMP_DIR/body.md}"
mise exec ruby -- ruby "$planner" render \
  --plan "$TEMP_DIR/project-plan.json" \
  --plan "$TEMP_DIR/global-plan.json" \
  --age "$report_age" \
  --title-file "$title_file" \
  --body-file "$body_file"
cat "$title_file" "$body_file"
