#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for example in \
  01-explicit-environments \
  02-local-overlay \
  03-profile-templates; do
  printf 'Testing %s\n' "$example"
  "$root/$example/test.sh"
done

echo "All Mise overlay examples passed"
