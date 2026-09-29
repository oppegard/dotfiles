# dotfiles

- We do not store secrets on the system in plaintext.

## Integration tests

Install Go 1.27 and mise, then run the suite from the repository root:

```sh
mise run test:integration
```

On a normal machine, this runs the installed pre-commit hook test in an
isolated repository and reports the bootstrap test as skipped. The bootstrap
test installs packages and changes machine settings. To run the full suite,
use a disposable macOS or Linux VM and run:

```sh
DOTFILES_INTEGRATION_DISPOSABLE=1 mise run test:integration
```

GitHub Actions runs the full suite on disposable macOS and Linux runners.

## MacOS Preferences

Managed macOS defaults live in
`files/home/.config/mise/config.macos.toml`. This repository tracks only
intentional preferences that are either documented by
[macos-defaults](https://github.com/yannbertrand/macos-defaults) or isolated by
a reviewed, single-setting before/after audit. It does not manage system-wide
defaults, third-party application state, or values merely because they appear
in a broad audit.

Run the commands in this section from the repository root. To add one
preference after changing it in System Settings:

```sh
mise -C files/home/.config/mise run macos-defaults:record
```

The interactive, vendored script captures a before/after diff in
`vendor/macos-defaults/diffs/<name>` (ignored by Git). Change **only one**
preference while it waits. Match the reported domain and key to the upstream
catalog; then add the typed value to
`files/home/.config/mise/config.macos.toml`, along with the upstream-derived
description and any documented activation action. Do not add a
preference merely because it appears in an audit or a diff.

For host-scoped or complex Apple preferences, use `bin/macos-defaults-audit` to
take focused before/after snapshots. Its reviewed `mise-candidates.toml` output
uses `[bootstrap.macos.defaults]` for ordinary preferences and
`[[bootstrap.macos.defaults_entries]]` with `host = "current"` for ByHost
preferences. Arrays and dictionaries are supported; plist dates and binary data
remain unsupported. The earlier fresh-user audit remains useful for broad
investigation, but it is not an import source because its candidates include
ordinary application and account state as well as preferences.

Check the mise-managed desired state without writing:

```sh
mise -C files/home/.config/mise bootstrap macos defaults status --missing
```

Inspect writes with `--dry-run`, then explicitly apply them:

```sh
mise -C files/home/.config/mise bootstrap macos defaults apply --dry-run
mise -C files/home/.config/mise bootstrap macos defaults apply
```

### BetterDisplay Prefs

On macOS, `bin/setup.sh` runs `mise run betterdisplay:export` to update the
portable synchronization profile at `files/macos/BetterDisplay.plist`.
The profile enables BetterDisplay's all-display `mostAppropriateBrightness`
synchronization without tracking machine-specific display identities or current
brightness values. Use `mise run betterdisplay:check` to inspect profile drift,
or `mise run betterdisplay:import` to apply it. Import asks for confirmation,
saves the current full preferences to `/tmp`, preserves local display-specific
preferences, and restarts BetterDisplay.

# Resources

## launchd

Website explaining launchd, LaunchAgents, and LaunchDaemons: [https://www.launchd.info](https://www.launchd.info)

[LaunchControl](https://www.soma-zone.com/LaunchControl/)
> LaunchControl is a fully-featured launchd GUI allowing you to create, manage and debug system- and user services on your Mac

## Third-Party Sites

- [Hard to discover tips and apps for making macOS pleasant](https://thume.ca/2020/09/04/macos-tips/)
- [https://sourabhbajaj.com/mac-setup/](https://sourabhbajaj.com/mac-setup/)
