# Return casks to Brewfile

## Status

Approved on 2026-09-30. Implementation and validation complete; PR creation
is in progress.

## Goal and reasoning

Manage all 31 currently configured Homebrew casks through Homebrew Bundle.
Mise leaves Homebrew-owned casks unchanged during upgrades and does not provide
a straightforward ownership transfer for them. Moving them to mise generally
requires uninstalling with `brew` and reinstalling through mise. That disruption
and the resulting mixed ownership are why cask management is returning to
Homebrew Bundle.

## Proposed changes

- Move every `brew-cask:` declaration from
  `files/home/.config/mise/config.macos.toml` into an alphabetized `# Casks`
  section in the root `Brewfile`, preserving the exact package names.
- Remove the unused `[bootstrap.brew] adopt = true` setting after removing
  the cask declarations. Keep formula and Mac App Store declarations in mise.
- Preserve Dock configuration, unrelated settings, and the user's uncommitted
  addition of `bootstrap packages upgrade` to `bin/setup.sh`.
- Include manual ownership repair instructions in the PR. Do not install,
  uninstall, move, or replace applications as part of this repository work.
- Explain in the main PR description that the lack of a straightforward
  migration without Homebrew uninstall/mise reinstall prompted this change.
- Create a ready PR with this plan and checklist in a collapsed
  `Implementation Plan` section. Do not merge or enable auto-merge without
  a further instruction for this PR.

## Installation findings and manual repair

All 31 configured casks have Caskroom entries. Of those, 29 have Homebrew
`.metadata` and no mise receipts. Only `cursor` and `visual-studio-code`
have `.mise-cask.toml` receipts and no Homebrew metadata. Homebrew's JSON info
reports both as not installed despite the app bundles and CLI links existing.

After the configuration change is available locally, quit Cursor and VS Code.
Download the current artifacts, then back up the two mise Caskroom records and
their three CLI links. The app bundles stay in `/Applications`. Let Homebrew
adopt those existing self-updating apps and create its own receipts and links:

```sh
brew fetch --cask cursor visual-studio-code
cask_backup_dir=$(mktemp -d "$HOME/cask-handoff.XXXXXX")
mkdir "$cask_backup_dir/cli" "$cask_backup_dir/caskroom"
mv /opt/homebrew/bin/code /opt/homebrew/bin/code-tunnel /opt/homebrew/bin/cursor "$cask_backup_dir/cli/"
mv /opt/homebrew/Caskroom/cursor /opt/homebrew/Caskroom/visual-studio-code "$cask_backup_dir/caskroom/"
brew install --cask --adopt cursor visual-studio-code
brew info --cask cursor visual-studio-code
code --version
cursor --version
```

Keep the backup until the apps and their CLI commands work. These commands
are specific to the inspected Apple Silicon Homebrew prefix and current
ownership state. Do not use `--zap`. If adoption fails, stop and inspect the
error before running Bundle; the original receipts and links remain backed up.
The other 29 casks need no ownership repair based on the inspected receipts.

Once adoption succeeds, reconcile declared packages with:

```sh
brew bundle install --file=/Users/glenn/src/dotfiles/Brewfile
```

## Checklist

- [x] Inventory all cask declarations and inspect installation ownership.
- [x] Identify manual repair commands for Cursor and VS Code.
- [x] Obtain approval for this plan before implementation.
- [x] Move all 31 casks into a separate Brewfile section.
- [x] Remove mise cask declarations and the unused cask adoption setting.
- [x] Verify the cask name sets match exactly and no duplicates remain.
- [x] Run `mise run lint`, `ruby -c Brewfile`, read-only Bundle listing,
  and `git diff --check`.
- [ ] Review the scoped diff, commit, and push the implementation.
- [ ] Open the PR with this plan and current checklist.

## Sources

- Homebrew install/adoption behavior:
  https://docs.brew.sh/Manpage.html#install-options-formulacask-
- Local Homebrew `cask/artifact/moved.rb`: self-updating apps can be adopted
  without replacing their live bundle.
- Installed Caskroom metadata and mise receipts inspected on 2026-09-30.
