# Bootstrap a new Mac

This checklist sets up a freshly installed Apple Silicon Mac from this
repository. Run commands in Terminal unless a step says otherwise.

The process is not read-only. It installs and upgrades command-line tools and
applications, links configuration into the home directory, changes macOS
defaults, changes the login shell, installs a LaunchAgent, writes
`/etc/pam.d/sudo_local`, runs `brew cleanup`, and opens several applications.
Use a current backup and read the checklist before starting.

This guide was checked on 2026-09-17 against this repository and mise
2026.9.10. Mise changes frequently, so recheck the linked upstream documentation
if the installed CLI behaves differently.

## Confidence labels

- **Verified here** means the command or behavior was exercised read-only on
  this Mac or in isolated mise config, data, cache, and state directories.
- **Repository-verified** means the behavior follows directly from the current
  scripts and configuration, but the complete step was not rerun on a clean Mac.
- **Lower confidence** means the step depends on a fresh macOS account, a
  private remote, an interactive installer, or a GUI path that was not exercised
  during this review. Follow the note and stop if actual behavior differs.

## Important assumptions

- The Mac is Apple Silicon. The repository sets the login shell to
  `/opt/homebrew/bin/bash`, which is Homebrew's Apple Silicon path.
- The checkout is exactly `~/src/dotfiles`. Several mise sources intentionally
  use that path.
- The GitHub repositories `oppegard/dotfiles` and `oppegard/setup` are
  accessible to the configured GitHub identity.
- `oppegard/dotfiles` stores declared configuration and symlink sources.
  `oppegard/setup` is a separate private mise history repository containing the
  live contents of `mode = "track"` files.
- The current tracked history is not encrypted. Keep `oppegard/setup` private.
  No age key is required by the current declarations.

## Before running `setup.sh`

### 1. Prepare macOS and accounts

- [ ] Install current macOS updates and restart the Mac if required.

  **Confidence: Lower confidence.** This was not exercised on a freshly erased
  Mac during this review.

- [ ] Confirm the account is an administrator and that its password works with
  `sudo`.

  Homebrew and mise's privileged bootstrap entries will ask for elevation.

  **Confidence: Repository-verified.** The privileged operations are visible in
  the Homebrew installer and `mise/config.macos.toml`; they were not applied
  during this review.

- [ ] Sign in to the Mac App Store with the Apple Account that owns Clocker.

  The Brewfile contains:

  ```ruby
  mas "Clocker", id: 1056643111
  ```

  **Confidence: Lower confidence.** Homebrew Bundle and `mas` document the App
  Store account requirement, but a new-account Clocker installation was not
  tested here.

- [ ] Install the 1Password desktop application from 1Password or the Mac App
  Store, sign in, and make the SSH key items available.

  The Brewfile installs `1password-cli`, not the 1Password desktop application.
  The managed SSH configuration later points at the 1Password SSH agent, and
  the managed Git configuration uses the 1Password application for SSH commit
  signing.

  **Confidence: Lower confidence.** The repository paths were verified, but the
  current 1Password first-run UI was not exercised.

### 2. Install Apple's command-line tools

- [ ] Start the Command Line Tools installer:

  ```sh
  xcode-select --install
  ```

  Wait for the installation to finish, then verify it:

  ```sh
  xcode-select -p
  git --version
  ```

  **Confidence: Lower confidence.** The commands are standard macOS commands,
  but the interactive installer was not rerun on this configured Mac.

### 3. Defer tool installation until after cloning

Homebrew, Homebrew Bash, and mise are installed together by `./bin/dotf run`
in Step 6. Continue with SSH access and cloning first; Apple's command-line
tools from Step 2 provide Git for the clone.

### 4. Restore the SSH key needed for GitHub

- [ ] Create the SSH directory with private permissions:

  ```sh
  install -d -m 700 "$HOME/.ssh"
  ```

- [ ] Securely restore `id_ed25519` from 1Password to
  `~/.ssh/id_ed25519`.

  If the work-only `memex_id_ed25519` key is needed on this Mac, restore it to
  `~/.ssh/memex_id_ed25519` too. Each file must contain its original OpenSSH
  private-key block, beginning with `-----BEGIN OPENSSH PRIVATE KEY-----`. Do
  not create an empty placeholder and do not paste a private key into a shell
  command, shell history, this repository, or this document.

- [ ] Set and verify private-key permissions:

  ```sh
  chmod 600 "$HOME/.ssh/id_ed25519"
  ssh-keygen -y -f "$HOME/.ssh/id_ed25519" >/dev/null
  ```

  On a work Mac with the additional key:

  ```sh
  chmod 600 "$HOME/.ssh/memex_id_ed25519"
  ssh-keygen -y -f "$HOME/.ssh/memex_id_ed25519" >/dev/null
  ```

- [ ] Verify GitHub SSH authentication:

  ```sh
  ssh -o BatchMode=yes -T git@github.com
  ```

  GitHub normally prints a successful-authentication greeting but exits with
  status 1 because it does not provide shell access.

  Do not manually create `~/.ssh/config` for this bootstrap. Mise will link the
  repository-owned version during dotfile application.

  **Confidence: Repository-verified.** The key names come from this repository's
  README, and the dotfiles remote is SSH. Key retrieval from 1Password and
  authentication from a newly installed Mac were not repeated here.

### 5. Clone this repository at its required path

- [ ] Clone and inspect the remote:

  ```sh
  mkdir -p "$HOME/src"
  git clone git@github.com:oppegard/dotfiles.git "$HOME/src/dotfiles"
  cd "$HOME/src/dotfiles"
  git remote -v
  ```

  Both fetch and push URLs should use `git@github.com`, not HTTPS.

  Do not create `~/.dotfiles`; `./bin/dotf run` will create it as a symlink to
  this checkout.

  **Confidence: Repository-verified.** The current origin and all hard-coded
  checkout sources were verified. A second clone was not made from GitHub.

### 6. Bootstrap Homebrew, Bash, and mise

- [ ] From the checkout, run:

  ```sh
  cd "$HOME/src/dotfiles"
  ./bin/dotf run
  ```

  This installs missing Homebrew, Homebrew Bash, and mise, verifies them, and
  stops. Existing tools are retained without upgrades. It requires a native
  Apple Silicon Terminal session and preserves the installers' prompts.
  It does not run `setup.sh` or restore private configuration.

  Bash must be installed early: mise configures `/opt/homebrew/bin/bash` as the
  login shell before `setup.sh` reaches the Brewfile. Bash remains declared in
  the Brewfile for subsequent setup runs.

- [ ] Apply the printed environment commands to this Terminal session:

  ```sh
  eval "$(/opt/homebrew/bin/brew shellenv bash)"
  export PATH="$HOME/.local/bin:$PATH"
  export MISE_AUTO_ENV=true
  ```

  A subprocess cannot change its parent shell's environment. The bootstrap
  does not edit shell startup files; mise later installs the managed files.
  Complete Steps 7–10 before running `setup.sh` in Step 11.

  **Confidence: Isolated checks only.** The bootstrap is checked with shell
  linting and stubbed installers. The real installers and a fresh-Mac run have
  not been exercised.

### 7. Select the machine profile for the first session

- [ ] Choose exactly one profile.

  For a personal Mac:

  ```sh
  export MISE_ENV=home
  ```

  For a work Mac:

  ```sh
  export MISE_ENV=work
  ```

- [ ] Enable platform configuration discovery for this first session:

  ```sh
  export MISE_AUTO_ENV=true
  printf 'MISE_ENV=%s MISE_AUTO_ENV=%s\n' "$MISE_ENV" "$MISE_AUTO_ENV"
  ```

  Do not create `~/.config/mise/miserc.toml` by hand. Dotfile application will
  render it. For a work Mac its expected contents are:

  ```toml
  env = ["work"]
  # automatically use config.{linux,macos}.toml
  auto_env = true
  ```

  A home Mac gets the same file with `env = ["home"]`.

  **Confidence: Verified here.** Both profiles were rendered from
  `mise/miserc.toml.tera` into an isolated mise configuration directory.

### 8. Adopt the separate mise history repository

- [ ] Review what the selected profile is expected to restore.

  The `work` profile currently has saved history for:

  - `~/.aws/config`
  - `~/.claude/settings.json`
  - `~/.codex/config.toml`
  - `~/.codex/rules/default.rules`
  - `~/src/drafthouse/mise.toml`

  The `home` profile currently has saved history for:

  - `~/.codex/config.toml`

  The repository declares a home variant for
  `~/.codex/rules/default.rules`, but that variant is not present in the current
  history tree. Do not assume it will be restored. See troubleshooting below.

- [ ] Adopt the private history over SSH and apply only dotfiles:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" bootstrap \
    --adopt git@github.com:oppegard/setup.git \
    --only dotfiles
  ```

  Review the proposed files before confirming. On a truly clean Mac the tracked
  targets should be absent. If mise reports a conflict, stop and inspect it; do
  not add `--replace-history` or `--force-dotfiles` as a shortcut.

  SSH is intentional. The checked-in Git configuration contains a
  version-specific GitHub HTTPS credential-helper path that is already stale on
  the reviewed Mac. SSH avoids that helper for both repositories.

- [ ] Verify the rendered profile, history origin, paths, and dotfile state:

  ```sh
  sed -n '1,20p' "$HOME/.config/mise/miserc.toml"
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles origin
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles paths
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles status
  ```

  The origin should be `git@github.com:oppegard/setup.git`, and the status should
  show the selected tracked paths plus repository-managed symlinks and templates.
  Do not print the contents of tracked AWS, Claude, or Codex files merely to
  verify that they exist.

  **Confidence: Mixed.** A synthetic profile-scoped tracked file was published
  to a local bare Git repository and successfully restored into separate
  isolated mise config/state directories using `bootstrap --adopt ... --only
  dotfiles`. The real private GitHub history, its SSH authorization, and a fresh
  macOS home directory were not used for that test.

### 9. Create the intentionally machine-local Git identity file

- [ ] Create `~/.config/git/local` as a regular, untracked file.

  For a personal Mac, its complete contents should be:

  ```gitconfig
  [user]
      email = oppegard@gmail.com
  ```

  For a work Mac, its complete contents should be:

  ```gitconfig
  [user]
      email = glenn.oppegard@focused.io
  ```

  Create it with an editor:

  ```sh
  mkdir -p "$HOME/.config/git"
  "${EDITOR:-vi}" "$HOME/.config/git/local"
  ```

  Then verify the effective identity without changing it:

  ```sh
  git config --global --includes --get user.name
  git config --global --includes --get user.email
  ```

  Do not put this machine-local file in the dotfiles repository. The
  `symlink-each` plus Git-manifest mapping deliberately leaves it alone.

  **Confidence: Verified here.** These choices and the untracked-file behavior
  match `files/home/.config/git/local.example` and the isolated symlink-each
  migration test previously run for this repository.

### 10. Seed BetterDisplay before `setup.sh` exports it

- [ ] Install BetterDisplay early:

  ```sh
  brew install --cask betterdisplay
  ```

- [ ] Import the portable repository profile before setup tries to export live
  preferences:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" run betterdisplay:import
  ```

  Confirm the task when prompted. It backs up the current BetterDisplay
  preference domain to `/tmp`, imports only the five portable synchronization
  keys, and opens BetterDisplay.

  If the import reports that the preference domain is unavailable, open
  BetterDisplay once, complete its first-run screen, quit it, and rerun the
  import:

  ```sh
  open -g -a BetterDisplay
  mise -C "$HOME/src/dotfiles/mise" run betterdisplay:import
  ```

  This step prevents a first-run cycle in `setup.sh`: the script installs
  BetterDisplay, immediately exports keys from its live preference domain, and
  only opens the application afterward.

  **Confidence: Lower confidence.** Static inspection confirms that a blank
  preference domain exports as an empty plist and then fails when the five keys
  are extracted. The existing import/check/export commands work on this Mac,
  but importing into a never-launched BetterDisplay installation was not
  performed because it would modify live preferences.

## Run `setup.sh`

### 11. Run the repository setup

- [ ] Keep the selected profile exported and start setup:

  ```sh
  cd "$HOME/src/dotfiles"
  printf 'Using mise profile: %s\n' "$MISE_ENV"
  ./bin/setup.sh
  ```

  The script performs these phases:

  1. Pulls the latest dotfiles commit over SSH.
  2. Installs mise-managed Gum for setup output.
  3. Reapplies mise bootstrap, including dotfiles, the history watcher,
     privileged files, macOS defaults, the login shell, and tools.
  4. Upgrades mise-managed tools within their declared version requests.
  5. Runs `brew bundle install` and then `brew cleanup`.
  6. Exports the live BetterDisplay portable keys back into the repository.
  7. Opens BetterDisplay, Clocker, and SoundSource in the background.

  Expect password, confirmation, application, and macOS permission prompts.
  Most phases are convergent, so after fixing a failed prerequisite, rerun the
  entire script unless a troubleshooting item below says otherwise.

  **Confidence: Repository-verified.** The script passes shell syntax and
  ShellCheck on the reviewed machine. It was not run against a new macOS user
  because it would install software and mutate system and user settings.

## Manual work after `setup.sh`

### 12. Start a fresh login shell

- [ ] Either close Terminal and open a new window, log out and back in, restart
  the Mac, or replace the current shell directly:

  ```sh
  exec /opt/homebrew/bin/bash -l
  ```

- [ ] Verify the shell and mise activation:

  ```sh
  printf '%s\n' "$SHELL"
  command -v bash
  command -v mise
  mise --version
  mise config ls
  ```

  `$SHELL` and `command -v bash` should resolve to `/opt/homebrew/bin/bash`, and
  `mise config ls` should include `config.macos.toml`.

  **Confidence: Repository-verified.** The startup chain and desired login shell
  were inspected. The account's login shell was not changed during this review.

### 13. Restart and verify the mise history watcher

- [ ] Reapply the service after setup so it uses the final mise executable and
  state directory:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" bootstrap services apply
  mise -C "$HOME/src/dotfiles/mise" bootstrap services status
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles status
  launchctl print "gui/$(id -u)/dev.mise.mise-history"
  ```

  `dotfiles status` should report automatic capture as running and watching this
  store. It should also show the SSH setup-repository origin.

  Do not run `mise dot sync` merely as a health check: sync may publish local
  tracked-file changes. Use status first and inspect anything pending.

  **Confidence: Mixed.** Status and LaunchAgent diagnostics were run read-only.
  The reviewed Mac currently reports that its older watcher should be restarted
  with `bootstrap services apply`; that mutation was intentionally not performed
  during this documentation review.

### 14. Verify convergence and repository cleanliness

- [ ] Run read-only checks:

  ```sh
  mise doctor
  mise -C "$HOME/src/dotfiles/mise" bootstrap status --missing
  mise -C "$HOME/src/dotfiles/mise" run betterdisplay:check
  brew bundle check --file="$HOME/src/dotfiles/Brewfile"
  git -C "$HOME/src/dotfiles" status --short
  ```

  Review, rather than automatically discarding, any repository change. In
  particular, `setup.sh` may update
  `files/macos/BetterDisplay.plist` if the live portable keys differ.

  **Confidence: Mixed.** Each command is supported by the current tools and
  repository. The whole set was not run after a clean bootstrap; `brew bundle
  check` can take time and may contact package services.

### 15. Complete GUI application setup

- [ ] Complete first-launch setup, licenses, login items, and requested macOS
  permissions for the applications installed by the Brewfile.

  At minimum, inspect:

  - BetterDisplay synchronization and its login-item setting.
  - Clocker's App Store installation, requested calendars, and login item.
  - SoundSource's audio component and login item.
  - 1Password's SSH agent and commit-signing prompts.
  - Rectangle Pro, LinearMouse, Ghostty, and other applications whose settings
    or permissions are machine-specific.

  A logout or restart is the simplest way to activate the new login shell and
  macOS settings that require application or session restarts.

  **Confidence: Lower confidence.** These application flows and macOS permission
  labels change between releases and were not reset and replayed.

### 16. Authenticate optional CLIs and services

- [ ] Authenticate GitHub CLI after mise has installed it, while keeping Git
  transport on SSH:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" exec gh -- \
    gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key
  ```

  Do not run `gh auth setup-git` until the checked-in version-specific HTTPS
  credential-helper entry has been repaired. It is not required for SSH remotes.

- [ ] On a work Mac, authenticate AWS, Drafthouse, Claude, Codex, and other
  services as needed. Mise history restores configuration files, not active
  login sessions, keychain items, browser sessions, or short-lived credentials.

  **Confidence: Mixed.** The GitHub CLI syntax is current and the repository
  installs `gh`; service-specific authentication was intentionally not tested or
  recorded here.

## Troubleshooting

### Mise is not found

- [ ] Restore the installer directory to this shell's `PATH` and retry:

  ```sh
  export PATH="$HOME/.local/bin:$PATH"
  mise --version
  ```

### A macOS task is missing or mise reports `no tasks defined`

- [ ] Restore first-run environment discovery and inspect the loaded configs:

  ```sh
  export MISE_AUTO_ENV=true
  export MISE_ENV=work  # use home instead on a personal Mac
  mise -C "$HOME/src/dotfiles/mise" config ls
  mise -C "$HOME/src/dotfiles/mise" tasks ls
  ```

- [ ] If `~/.config/mise/miserc.toml` is absent or stale, preview and then apply
  only that template:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles diff \
    "$HOME/.config/mise/miserc.toml"
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles apply --yes \
    "$HOME/.config/mise/miserc.toml"
  ```

  **Confidence: Verified here for rendering, not for this recovery on a fresh
  Mac.** Both profile values rendered correctly in isolation, and targeted
  template apply is supported by the installed mise CLI.

### History adoption reports conflicts

- [ ] Inspect status and the individual conflict:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles status
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles conflicts PATH
  ```

- [ ] After reviewing both versions, choose one path at a time.

  To take the setup repository's version:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles pull \
    --take-remote PATH
  ```

  To keep a local file, save it first and then resolve the conflict:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles save PATH
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles pull \
    --keep-local PATH
  ```

  Replace `PATH` with the exact path reported by mise. Do not copy a literal
  placeholder into the command.

  **Confidence: Lower confidence for the private remote.** The command behavior
  is from current mise help and documentation; no real tracked-file conflict was
  created or resolved during this review.

### The home Codex rules file was not restored

- [ ] Treat this as the known history gap, not as a successful restore.

  The current setup history has no home variant for
  `~/.codex/rules/default.rules`. Do not invent its contents. Either save the
  intended file from an existing home-profile machine before bootstrapping, or
  let Codex create the intended rules on the new Mac, review them, and then save
  that exact file:

  ```sh
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles save \
    "$HOME/.codex/rules/default.rules" \
    --description "save home Codex rules"
  ```

  Because the history origin defaults to sync mode, a saved checkpoint may be
  published by the watcher. Review the file before saving it.

  **Confidence: Repository-verified.** The declared home variant and missing
  path in the current history tree were checked without reading tracked-file
  contents. Creating a replacement was not attempted.

### BetterDisplay export fails during setup

- [ ] Install and open BetterDisplay, import the portable profile, then rerun
  setup:

  ```sh
  brew install --cask betterdisplay
  open -g -a BetterDisplay
  mise -C "$HOME/src/dotfiles/mise" run betterdisplay:import
  cd "$HOME/src/dotfiles"
  ./bin/setup.sh
  ```

  **Confidence: Lower confidence on a never-launched installation.** The failure
  path was reproduced with an empty preference domain, but the live application
  import was not reset and replayed.

### Homebrew Bundle stops at Clocker

- [ ] Open the Mac App Store, confirm the correct Apple Account is signed in,
  and obtain Clocker manually if the account has never acquired it. Then retry:

  ```sh
  brew bundle install --file="$HOME/src/dotfiles/Brewfile"
  cd "$HOME/src/dotfiles"
  ./bin/setup.sh
  ```

  **Confidence: Lower confidence.** This follows Homebrew Bundle and `mas`
  guidance; the failure was not recreated with a new Apple Account.

### GitHub authentication fails after dotfiles are applied

- [ ] Confirm both remotes use SSH:

  ```sh
  git -C "$HOME/src/dotfiles" remote get-url origin
  mise -C "$HOME/src/dotfiles/mise" bootstrap dotfiles origin
  ssh -o BatchMode=yes -T git@github.com
  ```

  If either remote is HTTPS, reconnect it to the corresponding SSH URL after
  reviewing the target. Do not depend on the checked-in version-specific `gh`
  credential-helper path.

  **Confidence: Verified here.** The stale helper and current failed HTTPS
  history fetch were observed read-only; the SSH workaround was not applied to
  the reviewed machine.

## Upstream references

- [Installing mise](https://mise.jdx.dev/installing-mise.html)
- [Set up a machine with mise](https://mise.jdx.dev/bootstrap/setup.html)
- [Mise dotfiles](https://mise.jdx.dev/dotfiles.html)
- [Mise dotfiles history](https://mise.jdx.dev/history.html)
- [Mise configuration environments](https://mise.jdx.dev/configuration/environments.html)
- [Homebrew Bundle and Brewfile](https://docs.brew.sh/Brew-Bundle-and-Brewfile)
- [Homebrew installation](https://brew.sh/)

## Validation performed for this guide

The following checks were run without changing the real mise history, tracked
files, history origin, watcher service, login shell, macOS defaults, or
BetterDisplay preferences:

- Rendered `mise/miserc.toml.tera` for both `home` and `work` into an isolated
  mise configuration directory.
- Created an isolated profile-scoped tracked file, saved it to a synthetic local
  bare Git origin, and restored it into separate mise config/state directories
  with `mise bootstrap --adopt ... --only dotfiles`.
- Ran an isolated login-shell dry run and observed mise plan the `/etc/shells`
  addition before `chsh`.
- Confirmed that an empty macOS preference domain exports an empty plist and
  that extracting BetterDisplay's required key then fails.
- Ran the current repository's dotfile bootstrap dry run with `MISE_ENV=work`
  and `MISE_AUTO_ENV=true`.
- Checked `bin/setup.sh` with `bash -n` and ShellCheck.
- Checked this file and the implementation plan with Markdownlint, and checked
  the repository diff for whitespace errors.

The complete checklist was not executed on a freshly erased Mac. In particular,
the real private history adoption, Apple and GitHub sign-ins, Homebrew and mise
installers, GUI first-launch flows, BetterDisplay import, macOS settings, and
history-watcher restart remain deliberately untested here and are labeled above.
