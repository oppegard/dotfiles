# Retained Stow Packages

The normal setup script still applies `codex` with Stow. This allows the
personal and optional `~/src/dotfiles-work` repositories to contribute
different files beneath `~/.codex`.

The following packages remain manual and are deferred from the mise migration:

- `borders`
- `hyprland`
- `keyd-application-mapper`
- `omarchy`
- `uwsm`
- `walker`
- `waybar`

Run home-level packages from this directory, where `.stowrc` is present. Add
`-n` to simulate a Stow operation before changing anything.

## Root-level packages

The root-owned `keyd` package is also deferred. Manage it separately from the
normal user bootstrap:

```sh
cd @root
sudo stow keyd
```
