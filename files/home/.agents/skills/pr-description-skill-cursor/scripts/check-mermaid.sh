#!/usr/bin/env bash
set -euo pipefail

draft=${1:?pass the draft path}

if ! command -v mmdc >/dev/null 2>&1; then
  echo "mmdc is not on PATH. The diagram is unchecked." >&2
  exit 2
fi

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

awk -v dir="$dir" '
  /^```mermaid$/ {
    n++
    f = dir "/diag" n ".mmd"
    while ((getline line) > 0 && line != "```") print line > f
    close(f)
  }
' "$draft"

shopt -s nullglob
files=("$dir"/diag*.mmd)
if (("${#files[@]}" == 0)); then
  echo "no mermaid block found" >&2
  exit 1
fi

fail=0
for f in "${files[@]}"; do
  mmdc -i "$f" -o "${f%.mmd}.svg" --quiet || fail=1
done
exit "$fail"
