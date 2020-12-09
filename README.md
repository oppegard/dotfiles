# dotfiles

- [Hard to discover tips and apps for making macOS pleasant](https://thume.ca/2020/09/04/macos-tips/)
- https://sourabhbajaj.com/mac-setup/

### Make cmd-tab app switcher appear on all monitors:
```
  defaults write com.apple.Dock appswitcher-all-displays -bool true
  killall Dock
```

## Enable TouchID Auth for `sudo` commands in iTerm2 ([source](https://antkowiak.it/en/mac-os-en/enable-touchid-for-sudo-in-iterm-2/)).
  1. Add `auth sufficient pam_tid.so` to the **top** of `/etc/pam.d/sudo`
  1. Go to iTerm2 Preferences (⌘,). In Advanced(⚙) Tab, search for "Allow sessions to survive logging out and back in." and set the value to No.
  1. Restart iTerm2 (maybe?)


## Enable QuickLook Plugins

```
for plugin in ~/Library/QuickLook/*qlgenerator; do
  echo enabling $plugin;
  xattr -d -r com.apple.quarantine ${plugin}
done
qlmanage -r
```

## Preferences

```sh
# Sublibe Settings
brew install coreutils # realpath
ln -sf $(realpath Preferences.sublime-settings) \
   ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/Preferences.sublime-settings

# Rectangle.app Settings
# Rectangle overwrite a symlinked prefs file. If changes are made to Rectangle prefs, we need to copy back to this repo.
cp com.knollsoft.Rectangle.plist \
   ~/Library/Preferences/com.knollsoft.Rectangle.plist

# Finder: show all hidden files
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder
```

## SSH Setup
From 1Password, copy `memex_id_ed25519` and `id_ed25519` to `~/.ssh/`.

```
chmod 0600 ~/.ssh/*id*
```