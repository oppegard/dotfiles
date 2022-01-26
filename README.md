# dotfiles

Another dotfiles repo.


# New Mac Setup

TODO: automate where sensible 🤖

## Install Fonts
- [IBM Plex Sans](https://fonts.google.com/specimen/IBM+Plex+Sans)
- [iA Writer Mono & Quattro](https://github.com/iaolo/iA-Fonts)
- Source Code Pro
  - *Sauce* Code variant preferred for [Starship](https://starship.rs/)
  - `brew tap homebrew/cask-fonts && brew install font-sauce-code-pro-nerd-font`
  - Assign font in iTerm and IntelliJ


## Make cmd-tab app switcher appear on all monitors:
```sh
  defaults write com.apple.Dock appswitcher-all-displays -bool true
  killall Dock
```


## Screenshots to save to ~/Desktop/Screenshots
```sh
defaults write  com.apple.screencapture location ~/Desktop/Screenshots
```


## Map ⌘ + ←Delete to backward-kill-line in iTerm2 + zsh
In iTerm2 have to ⌘ + ←Delete (⌘ + backspace) to send hex codes `0x18 0x7f`. Then ensure `bindkey ... backward-kill-line` is in `.zshrc`.

Detailed S.O. replies: [1](https://stackoverflow.com/a/32340345), [2](https://stackoverflow.com/questions/6205157/how-to-set-keyboard-shortcuts-to-jump-to-beginning-end-of-line/29403520#29403520).


## Enable TouchID Auth for `sudo` commands in iTerm2 ([source](https://antkowiak.it/en/mac-os-en/enable-touchid-for-sudo-in-iterm-2/)).
  1. Add `auth sufficient pam_tid.so` to the **top** of `/etc/pam.d/sudo`
  1. Go to iTerm2 Preferences (⌘,). In Advanced(⚙) Tab, search for "Allow sessions to survive logging out and back in." and set the value to No.
  1. Restart iTerm2 (maybe?)


## Enable QuickLook Plugins

```sh
for plugin in ~/Library/QuickLook/*qlgenerator; do
  echo enabling $plugin;
  xattr -d -r com.apple.quarantine ${plugin}
done
qlmanage -r
```


## Preferences

```sh
# Finder: show all hidden files
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder
```

### Rectangle.app Prefs
Launch Rectangle, open the Preferences pane, and import the prefs file (`Rectangle.json`)

### Firefox

Disable autoplay of YouTube Channel Trailers
- go to `about:config`
- `media.autoplay.default = 5`
- `media.autoplay.blocking_policy = 2`

[source](https://www.reddit.com/r/firefox/comments/hohrym/autoplay_settings_changed_blocking_seems_much/)


## SSH Setup
From 1Password, copy `memex_id_ed25519` and `id_ed25519` to `~/.ssh/`.

```sh
chmod 0600 ~/.ssh/*id*
```


# Resources

## Single Site Browsers (SSB)

[BZG](https://www.bzgapps.com) provides:
- Unite for WebKit-based SSB
- Coherence X

## launchd

Website explaining launchd, LaunchAgents, and LaunchDaemons: [https://www.launchd.info](https://www.launchd.info)

[LaunchControl](https://www.soma-zone.com/LaunchControl/)
> LaunchControl is a fully-featured launchd GUI allowing you to create, manage and debug system- and user services on your Mac


## Third-Party Sites

- [Hard to discover tips and apps for making macOS pleasant](https://thume.ca/2020/09/04/macos-tips/)
- [https://sourabhbajaj.com/mac-setup/](https://sourabhbajaj.com/mac-setup/)
