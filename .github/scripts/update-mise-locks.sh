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

age="${MISE_LOCK_MINIMUM_RELEASE_AGE:-7d}"
emergency="${MISE_LOCK_EMERGENCY_TOOL:-}"
planner="$REPO_DIR/.github/scripts/mise_lock_plan.py"
if [[ -n "$emergency" && ! "$emergency" =~ ^[A-Za-z0-9._:@/-]+$ ]]; then
  echo "updater refused emergency tool name" >&2
  exit 2
fi

mise_lock() {
  local config_dir=$1
  local global_flag=$2
  shift 2
  if [[ "$global_flag" == --global ]]; then
    MISE_CONFIG_DIR="$config_dir" mise lock --global "$@"
  else
    MISE_CONFIG_DIR="$config_dir" mise lock "$@"
  fi
}

lock_scope() {
  local scope=$1
  local config_dir=$2
  local global_flag=$3
  local aged="$TEMP_DIR/$scope-aged.json"
  local fresh="$TEMP_DIR/$scope-fresh.json"
  local plan="$TEMP_DIR/$scope-plan.json"
  local writes="$TEMP_DIR/$scope-writes.txt"
  local line tool write_age

  mise_lock "$config_dir" "$global_flag" --bump --dry-run --json --minimum-release-age "$age" >"$aged"
  mise_lock "$config_dir" "$global_flag" --bump --dry-run --json --minimum-release-age 0s >"$fresh"
  python3 "$planner" plan \
    --scope "$scope" \
    --aged "$aged" \
    --fresh "$fresh" \
    --age "$age" \
    --emergency-tool "$emergency" \
    --out "$plan" >"$writes"
  if [[ "${MISE_LOCK_DRY_RUN:-}" == 1 ]]; then
    return
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    tool="${line%% *}"
    write_age="${line#* }"
    if [[ "$tool" == "$line" || ! "$tool" =~ ^[A-Za-z0-9._:@/-]+$ ]]; then
      echo "updater refused tool name" >&2
      exit 2
    fi
    if [[ "$write_age" != "$age" && "$write_age" != 0s ]]; then
      echo "updater refused release age" >&2
      exit 2
    fi
    mise_lock "$config_dir" "$global_flag" --bump --json --minimum-release-age "$write_age" "$tool"
  done <"$writes"
}

cd "$REPO_DIR"
lock_scope project "$TEMP_DIR/global" ""
lock_scope global "$REPO_DIR/files/home/.config/mise" --global

title_file="${MISE_LOCK_PR_TITLE_FILE:-$TEMP_DIR/title.txt}"
body_file="${MISE_LOCK_PR_BODY_FILE:-$TEMP_DIR/body.md}"
python3 "$planner" render \
  --plan "$TEMP_DIR/project-plan.json" \
  --plan "$TEMP_DIR/global-plan.json" \
  --age "$age" \
  --emergency-tool "$emergency" \
  --title-file "$title_file" \
  --body-file "$body_file"
cat "$title_file" "$body_file"
