#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
STAGE="$TEMP_DIR/repo"
mkdir -p "$STAGE" "$TEMP_DIR/global" "$TEMP_DIR/system"
tar -chf - --exclude .git -C "$REPO_DIR" . | tar -xf - -C "$STAGE"

# File overrides bypass directory discovery and its environment overlays.
unset MISE_GLOBAL_CONFIG_FILE MISE_CONFIG_FILE MISE_GLOBAL_CONFIG_ROOT MISE_SYSTEM_CONFIG_FILE
unset MISE_OVERRIDE_CONFIG_FILENAMES MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES
unset MISE_INSTALLS_DIR MISE_DOWNLOADS_DIR MISE_INSTALL_PATH
unset BUNDLE_GEMFILE BUNDLE_PATH
export MISE_SYSTEM_CONFIG_DIR="$TEMP_DIR/system"
MISE_CEILING_PATHS="$(dirname "$STAGE")"
export MISE_CEILING_PATHS
export MISE_AUTO_ENV=false
export MISE_ENV=home
export MISE_SAFE=1
export MISE_LOCKFILE_AUTO_PRUNE=false
export MISE_CONFIG_DIR="$TEMP_DIR/global"
export MISE_DATA_DIR="$TEMP_DIR/runtime-data"
export MISE_CACHE_DIR="$TEMP_DIR/cache"
export MISE_STATE_DIR="$TEMP_DIR/state"
export MISE_SHIMS_DIR="$TEMP_DIR/shims"
export GEM_HOME="$TEMP_DIR/gems"
export GEM_PATH="$GEM_HOME"
export BUNDLE_IGNORE_CONFIG=1
export BUNDLE_USER_HOME="$TEMP_DIR/bundle"
export BUNDLE_USER_CACHE="$TEMP_DIR/bundle/cache"
export BUNDLE_USER_CONFIG="$TEMP_DIR/bundle/config"
export BUNDLE_USER_PLUGIN="$TEMP_DIR/bundle/plugin"
export BUNDLE_APP_CONFIG="$TEMP_DIR/bundle/app"

cd "$STAGE"
MISE_CONFIG_DIR="$STAGE/files/home/.config/mise" mise install --locked ruby
ruby="$(MISE_CONFIG_DIR="$STAGE/files/home/.config/mise" mise which ruby)"
planner="$STAGE/.github/scripts/mise_lock_plan.rb"
"$ruby" "$planner" artifacts --source "$REPO_DIR" --staged "$STAGE" --manifest "$TEMP_DIR/artifacts.json"
"$ruby" "$planner" snapshot --lock mise.lock --out "$TEMP_DIR/project-before.json"
"$ruby" "$planner" snapshot --lock files/home/.config/mise/mise.lock --out "$TEMP_DIR/global-before.json"
# Backend switching can reinstall tools. Keep its data separate from the planner runtime.
export MISE_DATA_DIR="$TEMP_DIR/tool-data"

config_age() {
  local value
  value="$(mise config get settings.minimum_release_age --file "$1")" || exit 1
  value="${value//[[:space:]]/}"
  if [[ -z "$value" ]]; then
    echo "updater requires minimum_release_age in $1" >&2
    exit 2
  fi
  printf '%s\n' "$value"
}

mise_scope() {
  local config_dir=$1
  local global_flag=$2
  local release_age=$3
  local command=$4
  shift 4
  if [[ "$global_flag" == --global ]]; then
    if [[ "$command" == lock ]]; then
      MISE_CONFIG_DIR="$config_dir" MISE_MINIMUM_RELEASE_AGE="$release_age" mise lock --global "$@"
    else
      MISE_CONFIG_DIR="$config_dir" MISE_MINIMUM_RELEASE_AGE="$release_age" mise "$command" "$@" --global
    fi
  else
    MISE_CONFIG_DIR="$config_dir" MISE_MINIMUM_RELEASE_AGE="$release_age" mise "$command" "$@"
  fi
}

update_scope() {
  local scope=$1
  local config_dir=$2
  local global_flag=$3
  local release_age=$4
  local lock=$5
  local aged="$TEMP_DIR/$scope-aged.json"
  local fresh="$TEMP_DIR/$scope-fresh.json"
  local migrated="$TEMP_DIR/$scope-migrated.json"
  local plan="$TEMP_DIR/$scope-plan.json"
  local writes="$TEMP_DIR/$scope-writes.txt"
  local tool

  mise_scope "$config_dir" "$global_flag" "$release_age" backends switch
  "$ruby" "$planner" snapshot --lock "$lock" --out "$migrated"
  "$ruby" "$planner" verify-migration --before "$TEMP_DIR/$scope-before.json" --after "$migrated"
  mise_scope "$config_dir" "$global_flag" "$release_age" lock --bump --dry-run --json >"$aged"
  mise_scope "$config_dir" "$global_flag" "$release_age" lock --bump --dry-run --json --minimum-release-age 0s >"$fresh"
  "$ruby" "$planner" plan --scope "$scope" --lock "$lock" --aged "$aged" --fresh "$fresh" --snapshot "$migrated" --out "$plan" >"$writes"
  while IFS= read -r tool; do
    [[ -n "$tool" ]] || continue
    mise_scope "$config_dir" "$global_flag" "$release_age" lock --bump --json -- "$tool"
  done <"$writes"
}

project_age="$(config_age "$STAGE/mise.toml")" || exit
global_age="$(config_age "$STAGE/files/home/.config/mise/config.toml")" || exit
update_scope project "$TEMP_DIR/global" "" "$project_age" "$STAGE/mise.lock"
update_scope global "$STAGE/files/home/.config/mise" --global "$global_age" "$STAGE/files/home/.config/mise/mise.lock"

for scope in project global; do
  lock="$STAGE/mise.lock"
  if [[ "$scope" == global ]]; then
    lock="$STAGE/files/home/.config/mise/mise.lock"
  fi
  "$ruby" "$planner" snapshot --lock "$lock" --out "$TEMP_DIR/$scope-after.json"
  "$ruby" "$planner" reconcile --scope "$scope" --lock "$lock" \
    --before "$TEMP_DIR/$scope-before.json" --migrated "$TEMP_DIR/$scope-migrated.json" \
    --after "$TEMP_DIR/$scope-after.json" --plan "$TEMP_DIR/$scope-plan.json" --fresh "$TEMP_DIR/$scope-fresh.json" \
    --out "$TEMP_DIR/$scope-records.json"
done

if [[ "$project_age" == "$global_age" ]]; then
  report_age=$project_age
else
  report_age="project $project_age, global $global_age"
fi
"$ruby" "$planner" render --plan "$TEMP_DIR/project-records.json" --plan "$TEMP_DIR/global-records.json" \
  --age "$report_age" --title-file "$TEMP_DIR/title.txt" --body-file "$TEMP_DIR/body.md"
if [[ "${MISE_LOCK_DRY_RUN:-}" != 1 ]]; then
  "$ruby" "$planner" artifacts --source "$REPO_DIR" --staged "$STAGE" --manifest "$TEMP_DIR/artifacts.json" --publish
fi
if [[ -n "${MISE_LOCK_PR_TITLE_FILE:-}" ]]; then
  cp "$TEMP_DIR/title.txt" "$MISE_LOCK_PR_TITLE_FILE"
fi
if [[ -n "${MISE_LOCK_PR_BODY_FILE:-}" ]]; then
  cp "$TEMP_DIR/body.md" "$MISE_LOCK_PR_BODY_FILE"
fi
cat "$TEMP_DIR/title.txt" "$TEMP_DIR/body.md"
