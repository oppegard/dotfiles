PATH=$HOME/bin:$HOME/.local/bin:/usr/local/sbin:$PATH
# Setting PATH for Python 3.9
PATH="/Library/Frameworks/Python.framework/Versions/3.9/bin:${PATH}"
export PATH
if [[ $(arch) -eq arm64 ]]; then
    eval $(/opt/homebrew/bin/brew shellenv)
fi
