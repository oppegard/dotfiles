alias l='ls -lFh'
alias la='ls -lFha'

# export VISUAL="/usr/local/bin/subl --new-window --wait"
export VISUAL="/usr/local/bin/idea -w"
export EDITOR=$VISUAL

bindkey "^X\\x7f" backward-kill-line

eval "$(starship init zsh)"
