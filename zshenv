# http://zsh.sourceforge.net/Doc/Release/Files.html#Startup_002fShutdown-Files
# 0. If ZDOTDIR is unset, HOME is used instead.
# 1. /etc/zshenv and then $ZDOTDIR/.zshenv
# 2. Login shell? /etc/zprofile and then $ZDOTDIR/.zprofile
# 3. Interactive login shell? /etc/zshrc and then $ZDOTDIR/.zshrc
# 4. Login shell? /etc/zlogin and $ZDOTDIR/.zlogin
# 5. Login shell exiting via `exit`? $ZDOTDIR/.zlogout and then /etc/zlogout

export HOMEBREW_NO_ANALYTICS=1