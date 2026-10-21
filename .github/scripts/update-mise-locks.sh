#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/global" "$TEMP_DIR/system"

# File overrides bypass directory discovery and its environment overlays.
unset MISE_GLOBAL_CONFIG_FILE MISE_GLOBAL_CONFIG_ROOT MISE_SYSTEM_CONFIG_FILE
unset MISE_OVERRIDE_CONFIG_FILENAMES MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES
export MISE_SYSTEM_CONFIG_DIR="$TEMP_DIR/system"
MISE_CEILING_PATHS="$(dirname "$REPO_DIR")"
export MISE_CEILING_PATHS
export MISE_AUTO_ENV=false
export MISE_ENV=home

cd "$REPO_DIR"
MISE_CONFIG_DIR="$TEMP_DIR/global" mise lock --bump
MISE_CONFIG_DIR="$REPO_DIR/files/home/.config/mise" mise lock --global --bump
