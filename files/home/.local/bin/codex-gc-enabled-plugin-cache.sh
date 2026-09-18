#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ts="$(date +%Y%m%d-%H%M%S)"
work="$CODEX_HOME/_cache-gc/$ts"
grave="$work/moved"

mkdir -p "$work" "$grave"

echo "Capturing current plugin state..."
codex plugin list --json > "$work/plugin-list.before.json"

jq -r '
  (.installed // [])
  | .[]
  | select(.enabled == true)
  | "\(.marketplaceName)/\(.name)"
' "$work/plugin-list.before.json" | sort -u > "$work/enabled-cache-keys.txt"

echo
echo "Enabled plugin cache keys:"
cat "$work/enabled-cache-keys.txt" || true
echo

echo "Stopping Codex app/server..."
osascript -e 'quit app "Codex"' 2>/dev/null || true
pkill -f 'codex.*app-server' 2>/dev/null || true

cache="$CODEX_HOME/plugins/cache"

if [ -d "$cache" ]; then
  echo "Pruning plugin cache: $cache"

  find "$cache" -mindepth 2 -maxdepth 2 -type d -print0 |
  while IFS= read -r -d '' dir; do
    marketplace="$(basename "$(dirname "$dir")")"
    plugin="$(basename "$dir")"
    key="$marketplace/$plugin"

    if grep -Fxq "$key" "$work/enabled-cache-keys.txt"; then
      echo "KEEP  $key"
    else
      dest="$grave/plugins/cache/$marketplace/$plugin"
      mkdir -p "$(dirname "$dest")"
      echo "MOVE  $key"
      mv "$dir" "$dest"
    fi
  done

  find "$cache" -mindepth 1 -type d -empty -delete 2>/dev/null || true
else
  echo "No plugin cache found at: $cache"
fi

echo
echo "Resetting temporary marketplace indexes..."
for p in \
  "$CODEX_HOME/.tmp/marketplaces" \
  "$CODEX_HOME/.tmp/bundled-marketplaces" \
  "$CODEX_HOME/.tmp/plugins"
do
  [ -e "$p" ] || continue
  mkdir -p "$grave/.tmp"
  echo "MOVE  $p"
  mv "$p" "$grave/.tmp/$(basename "$p")"
done

echo
echo "Done."
echo "Moved stale artifacts to:"
echo "  $grave"
echo
echo "Restart Codex."
echo "Optional refresh:"
echo "  codex plugin marketplace upgrade"
