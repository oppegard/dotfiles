# http://zsh.sourceforge.net/Doc/Release/Files.html#Startup_002fShutdown-Files
# 0. If ZDOTDIR is unset, HOME is used instead.
# 1. /etc/zshenv and then $ZDOTDIR/.zshenv
# 2. Login shell? /etc/zprofile and then $ZDOTDIR/.zprofile
# 3. Interactive login shell? /etc/zshrc and then $ZDOTDIR/.zshrc
# 4. Login shell? /etc/zlogin and $ZDOTDIR/.zlogin
# 5. Login shell exiting via `exit`? $ZDOTDIR/.zlogout and then /etc/zlogout

export HOMEBREW_NO_ANALYTICS=1
export GOPATH="${HOME}/src/go"

##### XDG #####
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_BIN_HOME="${HOME}/.local/bin"

##### PATH #####
# zsh is "smart" and removes dirs from PATH that don't exist
PATH="/Library/Frameworks/Python.framework/Versions/3.9/bin:${PATH}" # Python 3.9 for...?
PATH="${GOPATH:-$HOME/src/go}/bin:${PATH}" # GOBIN
PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
PATH="/Applications/IntelliJ IDEA.app/Contents/MacOS:$PATH"
PATH="${HOME}/.cicd/bin:${PATH}"

PATH="${XDG_BIN_HOME}:${HOME}/bin:/usr/local/sbin:${PATH}"
export PATH
