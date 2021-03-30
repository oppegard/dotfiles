export JAVA_HOME=$(/usr/libexec/java_home -v 11)
if [[ -e /opt/homebrew/bin/brew ]]; then
    eval $(/opt/homebrew/bin/brew shellenv)
fi
