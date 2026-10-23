# dotfiles

- We do not store secrets on the system in plaintext.

## Lint

Run `mise run lint` to check all files. Run `mise run lint-fix` to apply safe
fixes. Both commands use `hk.pkl`. GitHub Actions workflows use jactionlint
with the pedantic profile in `.github/jactionlint.yaml`. Markdown uses rumdl.
`.rumdl.toml` turns off line-length checks.

## Update project tools

Run these commands from the repository root. Install the versions in `mise.lock`:

```sh
mise install --locked
```

To update a tool within its `mise.toml` request, regenerate the lock with a 7
day age window, then check and review the changes.

```sh
mise lock --bump --minimum-release-age 7d shellcheck
mise install --locked
mise run lint
mise run test:integration
git diff -- mise.toml mise.lock
```

Use `mise lock` to refresh lock metadata without changing the locked versions.
The lock covers Linux x64 and macOS arm64. Mise reads the Go version from
`go.mod`; after changing that version or a tool request, run `mise lock` again.
Commit `mise.toml`, `go.mod`, and `mise.lock` changes together when applicable.

## Update global tools

Bootstrap installs the versions in
`files/home/.config/mise/mise.lock` with `--locked`. The lock covers Linux x64
and macOS arm64. Mise links it to `~/.config/mise/mise.lock`; native dependency
sidecars in the adjacent `locks/` directory stay in the checkout.

After bootstrap, update one global tool within its `config.toml` request. Use
the same 7 day age window.

```sh
mise lock --global --bump --minimum-release-age 7d shellcheck
mise -C ~ install --locked
mise run lint
mise run test:integration
git diff -- files/home/.config/mise/config.toml files/home/.config/mise/mise.lock files/home/.config/mise/locks
```

Use `mise lock --global` to refresh metadata without changing locked versions.
Commit the global config, lock, and generated sidecars together when applicable.
Keep sidecars as generated; the lock verifies their content digest.
`bin/setup.sh` still performs deliberate tool upgrades.

## Update locks on a schedule

The `Update mise locks` workflow opens a pull request for `mise.lock` and
`files/home/.config/mise/mise.lock`. It resolves each tool with
`--minimum-release-age 7d` and locks a version only when that resolution is
newer than the committed lock. A prefix request such as `2` or `1.27` stays
inside that prefix. Mise does not refuse a major bump of a `latest` or `lts`
request, and this workflow does not add a filter for one. The workflow sets
`MISE_SAFE=1`. Safe mode hides the Go version read from `go.mod`, so the job
does not bump that pin. After changing `go.mod`, run `mise lock` yourself. A
run that only finds versions inside the age window does not open a pull
request, because no lock file changes.

To bypass the age window for one tool, run the workflow and set
`emergency_tool` to that tool's name. The run passes
`--minimum-release-age 0s` for that name only. If that name is not adopted,
the run fails before it writes a lock.

Set repository secrets `MISE_LOCKS_APP_ID` and `MISE_LOCKS_APP_PRIVATE_KEY`
when pull request checks should start on their own. The workflow passes the
app id to `actions/create-github-app-token`. That input is deprecated in favor
of `client-id`. Without the secrets, the workflow uses `GITHUB_TOKEN` and
dispatches `lint.yml` and `integration-tests.yml`.

Set repository variable `MISE_LOCKS_AUTOMERGE` to `true` to turn on auto-merge
for the lock pull request. Leave the variable unset to keep auto-merge off.
Auto-merge cannot skip a major bump of a `latest` or `lts` tool. Allow
auto-merge in the repository settings, and require the checks `Lint`,
`Integration test (macos-latest)`, and `Integration test (ubuntu-26.04)`.
If more than one merge method is allowed, `gh pr merge --auto` will not pick
one, so allow a single method before turning the variable on.

## Integration tests

Install mise, then run the suite from the repository root. Mise selects the Go
version from the root `go.mod`:

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

## Resources

### launchd

Website explaining launchd, LaunchAgents, and LaunchDaemons: [https://www.launchd.info](https://www.launchd.info)

[LaunchControl](https://www.soma-zone.com/LaunchControl/)
> LaunchControl is a fully-featured launchd GUI allowing you to create, manage and debug system- and user services on your Mac

### Third-Party Sites

- [Hard to discover tips and apps for making macOS pleasant](https://thume.ca/2020/09/04/macos-tips/)
- [https://sourabhbajaj.com/mac-setup/](https://sourabhbajaj.com/mac-setup/)
