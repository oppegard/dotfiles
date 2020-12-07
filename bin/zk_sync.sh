#!/usr/bin/env bash
set -e

export GIT_SSH_COMMAND="ssh -i ~/.ssh/memex_id_ed25519"
ZK_PATH="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Memex"
cd "$ZK_PATH"
git pull

CHANGES_EXIST="$(git status — porcelain | wc -l)"
if [ "$CHANGES_EXIST" -eq 0 ]; then
  date +"%Y-%m-%d %H:%M:%S %Z" >> $HOME/Downloads/zksync
  exit 0
fi

git add .
git commit -q -m "$(date +"%Y-%m-%d %H:%M:%S %Z")"
git push -q

date +"%Y-%m-%d %H:%M:%S %Z" >> $HOME/Downloads/zksync