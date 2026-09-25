# Move Dock app installation to mise packages

## Status

Approved and completed on 2026-09-25.

## Goal and reasoning

Make the macOS Dock app list and the mise package declarations agree, so mise
bootstrap packages covers each Dock app's installation source. Keep the existing
Dock paths and other Brewfile entries intact. A Homebrew cask exists for
Mimestream, so use `brew-cask` as selected; this also lets mise recognize the
current Homebrew-owned installation without replacing its app bundle.

## Proposed changes

| Dock app | mise package | Current Brewfile entry |
| --- | --- | --- |
| Google Chrome | `brew-cask:google-chrome` | cask |
| Mimestream | `brew-cask:mimestream` | cask |
| Fantastical | `brew-cask:fantastical` | cask |
| Slack | `brew-cask:slack` | cask |
| ChatGPT | `brew-cask:chatgpt` | cask |
| Things 3 | `mas:904280696` | mas |
| Obsidian | `brew-cask:obsidian` | cask |
| Ghostty | `brew-cask:ghostty` | cask |
| IntelliJ IDEA | `brew-cask:jetbrains-toolbox` | cask |
| Sublime Text | `brew-cask:sublime-text` | cask |

- Add these ten entries to `files/home/.config/mise/config.macos.toml` under
  `[bootstrap.packages]`. Toolbox provides IntelliJ IDEA through its own app
  installer; the Toolbox cask does not itself install the IDE bundle.
- Add `brew:mas` as the `mas:` manager prerequisite. The current machine has
  `mas`, but mise's documentation says a fresh full bootstrap does not make a
  newly declared `mas` tool available before the packages phase. A fresh Mac
  must install `mas` before applying the Things 3 declaration, or repeat the
  package apply after it becomes available.
- Remove only the corresponding nine cask entries and Things 3 entry from the
  root `Brewfile`. Retain unrelated casks, formulae, and App Store entries.
- Do not install, remove, or replace apps on this Mac as part of the repository
  change. Existing Homebrew-owned casks can satisfy matching mise declarations.

## Checklist

- [x] Inventory Dock paths, Brewfile entries, installed `mas`, and current
  first-party mise package guidance.
- [x] Add the ten app declarations and the `mas` prerequisite in the macOS
  mise config.
- [x] Remove matching entries from `Brewfile` without changing other packages.
- [x] Validate TOML, the exact Dock-to-package mapping, the Brewfile diff,
  and mise's read-only package status/dry run; run applicable lint checks.
- [x] Review the final diff, commit with a Conventional Commit message, and
  push the current branch without including unrelated worktree files.

## Verification

- The `[bootstrap.packages]` section parses as TOML and has all ten mapped apps
  and `brew:mas`. Ruby reports `Brewfile` syntax OK, and none of the moved apps
  remains in it.
- `mise bootstrap packages status --json` reports all declared casks and
  Things 3 installed. `mise bootstrap packages apply --dry-run` reports three
  brew packages, ten casks, and one App Store package already installed.
- `hk check --all --verbose` passed its gitleaks check; `git diff --check`
  passed.
- Full-file `taplo check` fails on multiline inline tables already present in
  `config.macos.toml` at `HEAD`. The changed package section parses, and mise
  loads the complete file for status and dry run.

## References

- [mise bootstrap packages](https://mise.jdx.dev/bootstrap/packages/)
- [mise Homebrew casks](https://mise.jdx.dev/bootstrap/packages/brew.html)
- [mise Mac App Store apps](https://mise.jdx.dev/bootstrap/packages/mas.html)
