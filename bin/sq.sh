#!/bin/bash
set -euxo pipefail
USERNAME=goppegard

branch=$(git branch --show-current)

if [[ $branch != $USERNAME/* ]]; then
  echo "Can't determine feature branch from '$branch'"
  exit 1
fi

git rebase -i master
git fetch origin
git rebase origin/master

# Use '#' to remove "$USERNAME/" string from $branch var
# https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
git checkout -b "sq-$USERNAME-${branch#$USERNAME/}"