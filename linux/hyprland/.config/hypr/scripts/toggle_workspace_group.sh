#!/usr/bin/env bash
# Toggle “all-in-one-tab” mode for the current workspace.
set -e
set -x

# 1. What workspace are we on?
ws="$(hyprctl activeworkspace -j | jq -r '.id')"

# 2. Collect all window addresses on that workspace.
mapfile -t addrs < <(hyprctl clients -j \
  | jq -r ".[] | select(.workspace.id==$ws) | .address")

# Nothing to do if the workspace is empty.
[[ ${#addrs[@]} -eq 0 ]] && exit 0

# 3. Decide: already grouped?
grouped="$(hyprctl clients -j \
  | jq -r ".[] | select(.workspace.id==$ws and .group.id!=null)" \
  | wc -l)"

if [[ $grouped -eq 0 ]]; then
  #### --------  GROUP EVERYTHING  --------
  first="${addrs[0]}"
  hyprctl dispatch focuswindow "address:$first"
  hyprctl dispatch togglegroup                 # create new group
#  hyprctl dispatch lockactivegroup lock        # keep future windows in

  # move the rest (direction is irrelevant as long as it's consistent)
  for addr in "${addrs[@]:1}"; do
    hyprctl dispatch focuswindow "address:$addr"
    hyprctl dispatch moveintogroup l
  done
else
  #### --------  UNGROUP EVERYTHING  --------
  # focus any member of the group
  root="$(hyprctl clients -j \
          | jq -r ".[] | select(.workspace.id==$ws and .group.id!=null) | .address" \
          | head -n1)"
  hyprctl dispatch focuswindow "address:$root"
#  hyprctl dispatch lockactivegroup unlock

  # repeatedly pop windows out until this one is no longer grouped
  while hyprctl activewindow -j | jq -e '.group.id!=null' >/dev/null; do
    hyprctl dispatch moveoutofgroup
  done
fi

