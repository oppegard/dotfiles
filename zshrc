# zmodload zsh/zprof # Profile startup. Also uncomment `zprof` line at bottom.

alias l='ls -lFh'
alias la='ls -lFha'
alias ports='lsof -nP -iTCP -sTCP:LISTEN'

export CLICOLOR=true # colors in `ls`

############### BAT ################
#  https://github.com/sharkdp/bat ##
####################################
alias cat='bat --paging=never --style=plain'
alias less='bat'
export MANPAGER="sh -c 'col -bx | bat -l man -p'"


############### WORK START ###############
if [[ `hostname` == "goppegard-a01" ]]; then

ssh-add -l | grep -q 'SHA256:wGrO2n9iXDV0Tv5k6QccgyO4TGGxCAvk80A8mxiYA+w' || ssh-add ~/.ssh/ec2key.pem
ssh-add -l | grep -q 'SHA256:ZLtBR8T2gu9pZsEQxa8s/c+nTy9L5dEIVnkh4rei93A' || ssh-add ~/.ssh/prodkey.pem

fi
##### WORK END   #####


############### HISTORY CONFIGURATION ###############
SAVEHIST=5000
HISTSIZE=5000
setopt EXTENDED_HISTORY  #Save command timestamp and the duration to the history file.
setopt APPEND_HISTORY    #Append history to the history file (no overwriting)
setopt histignorespace   # prevent line from being saved if it beging with a space
setopt HIST_IGNORE_ALL_DUPS # If a new command line being added to the history list duplicates an older one, the older command is removed from the list (even if it is not the previous event).
# setopt HIST_FIND_NO_DUPS # When searching for history entries in the line editor, do not display duplicates of a line previously found, even if the duplicates are not contiguous.


############### MISCELLANEOUS ###############

setopt interactivecomments # allow use of '#' for comments on CLI
bindkey "^X\\x7f" backward-kill-line

export GIT_DUET_GLOBAL=true
export GIT_DUET_CO_AUTHORED_BY=true
export GIT_DUET_ROTATE_AUTHOR=false

eval "$(direnv hook zsh)"
eval "$(starship init zsh)"
source $HOME/bin/z.sh

alias tailscale=/Applications/Tailscale.app/Contents/MacOS/Tailscale

############### PYTHON ###############
BREW_PREFIX=$(brew --prefix)
if [[ -e $BREW_PREFIX/bin/virtualenvwrapper.sh ]]; then
    export VIRTUALENVWRAPPER_PYTHON=$BREW_PREFIX/bin/python3
    export WORKON_HOME=$HOME/.virtualenvs
    source $BREW_PREFIX/bin/virtualenvwrapper.sh
fi


############### EDITOR CONFIGURATION ###############
# export VISUAL="/usr/local/bin/subl --new-window --wait"
# export VISUAL="/usr/local/bin/idea -w -e"
# export EDITOR=$VISUAL
alias vim='nvim'
alias vi='nvim'


############### AUTOCOMPLETE ###############

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


############### HOMEBREW & ASDF ###############
if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
#  source "$(brew --prefix asdf)/libexec/asdf.sh"
#  . ~/.asdf/plugins/java/set-java-home.zsh
#  export PATH="${JAVA_HOME/bin}:$PATH"
fi


# autoload and compinit have to come after any updates to FPATH var
autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done
compinit -C

export JAVA_HOME=$(/usr/libexec/java_home -v 17)


test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
alias k=kubectl

# zprof # print zsh profiling timesource "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"

# Hook for local customizations or sensitive data that shouldn't be committed
[[ -f "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
eval "$(mise activate zsh)"
