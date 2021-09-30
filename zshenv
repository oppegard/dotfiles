# http://zsh.sourceforge.net/Doc/Release/Files.html#Startup_002fShutdown-Files
# 0. If ZDOTDIR is unset, HOME is used instead.
# 1. /etc/zshenv and then $ZDOTDIR/.zshenv
# 2. Login shell? /etc/zprofile and then $ZDOTDIR/.zprofile
# 3. Interactive login shell? /etc/zshrc and then $ZDOTDIR/.zshrc
# 4. Login shell? /etc/zlogin and $ZDOTDIR/.zlogin
# 5. Login shell exiting via `exit`? $ZDOTDIR/.zlogout and then /etc/zlogout

export HOMEBREW_NO_ANALYTICS=1

##### PATH #####
# zsh is "smart" and removes dirs from PATH that don't exist
PATH="${HOME}/.local/bin:${PATH}" # pipx
PATH="/Library/Frameworks/Python.framework/Versions/3.9/bin:${PATH}" # Python 3.9 for...?
PATH="${GOPATH:-$HOME/go}/bin:${PATH}" # GOBIN

PATH="${HOME}/bin:/usr/local/sbin:${PATH}"
export PATH
