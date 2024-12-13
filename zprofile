if [[ -e /opt/homebrew/bin/brew ]]; then
    eval $(/opt/homebrew/bin/brew shellenv)
fi

# Added by `rbenv init` on Sun Sep 29 23:11:32 MDT 2024
# Disabling rbenv Dec 2024 to try mise
# eval "$(rbenv init - --no-rehash zsh)"
eval "$(mise activate zsh --shims)"
