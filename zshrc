alias l='ls -lFh'
alias la='ls -lFha'

##### HISTORY CONFIGURATION #####
SAVEHIST=5000
HISTSIZE=5000
setopt EXTENDED_HISTORY  #Save command timestamp and the duration to the history file.
setopt APPEND_HISTORY    #Append history to the history file (no overwriting)


##### EDITOR CONFIGURATION #####
# export VISUAL="/usr/local/bin/subl --new-window --wait"
# export VISUAL="/usr/local/bin/idea -w -e"
# export EDITOR=$VISUAL

bindkey "^X\\x7f" backward-kill-line

export GIT_DUET_ROTATE_AUTHOR=true

eval "$(direnv hook zsh)"
eval "$(starship init zsh)"

# autocompletion
autoload -U compinit && compinit