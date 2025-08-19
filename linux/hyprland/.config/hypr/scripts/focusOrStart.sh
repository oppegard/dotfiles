#!/bin/bash
execCommand=$1
className=$2
workspaceOnStart=$3

#echo "*** $execCommand ***" >>/tmp/bar
#echo "*** $className ***" >>/tmp/bar
#echo "*** $workspaceOnStart ***" >>/tmp/bar

running=$(hyprctl -j clients | jq -r ".[] | select(.class == \"${className}\") | .workspace.id")
echo $running

if [[ $running != "" ]]; then
  echo "focus"
  hyprctl dispatch focuswindow class:"${className}"
else
  echo "start"
  hyprctl dispatch workspace $workspaceOnStart
  ${execCommand} &
fi
