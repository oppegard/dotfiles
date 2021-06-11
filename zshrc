alias l='ls -lFh'
alias la='ls -lFha'

##### TObs START #####
ssh-add -l | grep -q 'SHA256:wGrO2n9iXDV0Tv5k6QccgyO4TGGxCAvk80A8mxiYA+w' || ssh-add ~/.ssh/ec2key.pem
ssh-add -l | grep -q 'SHA256:ZLtBR8T2gu9pZsEQxa8s/c+nTy9L5dEIVnkh4rei93A' || ssh-add ~/.ssh/prodkey.pem
##### TObs END   #####


##### HISTORY CONFIGURATION #####
SAVEHIST=5000
HISTSIZE=5000
setopt EXTENDED_HISTORY  #Save command timestamp and the duration to the history file.
setopt APPEND_HISTORY    #Append history to the history file (no overwriting)


##### MISCELLANEOUS #####

setopt interactivecomments # allow use of '#' for comments on CLI


##### EDITOR CONFIGURATION #####
# export VISUAL="/usr/local/bin/subl --new-window --wait"
# export VISUAL="/usr/local/bin/idea -w -e"
# export EDITOR=$VISUAL

bindkey "^X\\x7f" backward-kill-line

export GIT_DUET_ROTATE_AUTHOR=true

eval "$(direnv hook zsh)"
eval "$(starship init zsh)"


##### AUTOCOMPLETE #####

# The code below sets all of `zsh-autocomplete`'s settings.
# https://github.com/marlonrichert/zsh-autocomplete/blob/main/.zshrc

zstyle ':autocomplete:*' default-context ''
# '': Start each new command line with normal autocompletion.
# history-incremental-search-backward: Start in live history search mode.

zstyle ':autocomplete:*' min-delay 0.0  # number of seconds (float)
# 0.0: Start autocompletion immediately when you stop typing.
# 0.4: Wait 0.4 seconds for more keyboard input before showing completions.

zstyle ':autocomplete:*' min-input 0  # number of characters (integer)
# 0: Show completions immediately on each new command line.
# 1: Wait for at least 1 character of input.

zstyle ':autocomplete:*' ignored-input '' # extended glob pattern
# '':     Always show completions.
# '..##': Don't show completions when the input consists of two or more dots.

# When completions don't fit on screen, show up to this many lines:
zstyle ':autocomplete:*' list-lines 16  # (integer)
# 💡 NOTE: The actual amount shown can be less.

# If any of the following are shown at the same time, list them in this order:
zstyle ':completion:*:' group-order \
    expansions history-words options \
    aliases functions builtins reserved-words \
    executables local-directories directories suffix-aliases
# 💡 NOTE: This is NOT the order in which they are generated.

zstyle ':autocomplete:*' insert-unambiguous no
# no:  Tab inserts the top completion.
# yes: Tab first inserts substring common to all listed completions, if any.

zstyle ':autocomplete:*' widget-style complete-word
# complete-word: (Shift-)Tab inserts the top (bottom) completion.
# menu-complete: Press again to cycle to next (previous) completion.
# menu-select:   Same as `menu-complete`, but updates selection in menu.
# ⚠️ NOTE: This can NOT be changed at runtime.

zstyle ':autocomplete:*' fzf-completion no
# no:  Tab uses Zsh's completion system only.
# yes: Tab first tries Fzf's completion, then falls back to Zsh's.
# ⚠️ NOTE: This can NOT be changed at runtime and requires that you have
# installed Fzf's shell extensions.

# Add a space after these completions:
zstyle ':autocomplete:*' add-space \
    executables aliases functions builtins reserved-words commands

autoload -Uz compinit
compinit
