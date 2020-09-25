# dotfiles

- [Hard to discover tips and apps for making macOS pleasant](https://thume.ca/2020/09/04/macos-tips/)

- Make cmd-tab app switcher appear on all monitors:
```
  defaults write com.apple.Dock appswitcher-all-displays -bool true
  killall Dock
```
