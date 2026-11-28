#!/bin/bash
# Validate every ```mermaid block in a Markdown file with mmdc.
# Exit 0: all blocks valid (or none). Exit 1: a block is invalid.
# Exit 2: usage error, missing mmdc, or an unterminated block.

set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo "usage: ${0##*/} <file.md>" >&2
  exit 2
fi
if ! command -v mmdc >/dev/null; then
  echo "mmdc not found; install npm:@mermaid-js/mermaid-cli with mise" >&2
  exit 2
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Write block N to $workdir/N.mmd and its opening line number to N.line.
awk -v dir="$workdir" '
  /^[[:space:]]*```mermaid[[:space:]]*$/ && !inside {
    inside = 1; n++; file = dir "/" n ".mmd"
    print NR > (dir "/" n ".line"); close(dir "/" n ".line")
    printf "" > file
    next
  }
  /^[[:space:]]*```[[:space:]]*$/ && inside { inside = 0; close(file); next }
  inside { print > file }
  END { if (inside) { print "unterminated mermaid block at end of file" > "/dev/stderr"; exit 2 } }
' "$1"

shopt -s nullglob
blocks=("$workdir"/*.mmd)
if [[ ${#blocks[@]} -eq 0 ]]; then
  echo "no mermaid blocks in $1"
  exit 0
fi

failed=0
# Glob order is lexical (10 before 2); walk the blocks in document order.
for ((n = 1; n <= ${#blocks[@]}; n++)); do
  line=$(<"$workdir/$n.line")
  if output=$(mmdc --quiet --input "$workdir/$n.mmd" \
    --output "$workdir/$n.svg" 2>&1); then
    echo "ok      block $n (line $line)"
  else
    echo "INVALID block $n (line $line)"
    # Keep the parse error; drop the Puppeteer stack trace.
    sed '/^[[:space:]]*at /d; /^Parser\./d; /^$/d; s/^/        /' <<<"$output"
    failed=1
  fi
done
exit "$failed"
