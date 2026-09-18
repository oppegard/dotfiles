# Document the new-Mac bootstrap process

## Status

Implemented and verified on 2026-09-17.

## Goal

Create a root-level Markdown guide named `Bootstrap.me` that explains how to
set up a freshly installed Mac from this repository, including prerequisites,
the required order of operations, mise profile and tracked-history restoration,
known first-run cycles, and manual follow-up work.

## Scope

- Document the current repository behavior without changing `bin/setup.sh` or
  mise configuration.
- Target an Apple Silicon Mac. The current login-shell declaration is the
  Apple Silicon Homebrew path `/opt/homebrew/bin/bash`.
- Use the repository's exact checkout path, `~/src/dotfiles`, because the mise
  dotfile sources refer to it directly.
- Cover both `home` and `work` mise profiles.
- Explain the difference between files stored in this Git repository and
  `mode = "track"` files stored in mise's separate history repository.

## Repository findings to capture

1. `bin/setup.sh` requires `mise` to be installed and on `PATH`, and begins with
   `git pull`, so repository-host authentication must already work.
2. Homebrew is also a prerequisite. The script invokes `brew bundle`, but does
   not install Homebrew.
3. `mise bootstrap` runs before the Brewfile. The macOS configuration asks mise
   to set `/opt/homebrew/bin/bash` as the login shell, while Bash is installed
   by the later Brewfile step. A clean machine therefore needs Homebrew Bash
   before `setup.sh`, unless the bootstrap implementation is changed.
4. The previous mise template cycle is fixed in the current script: bootstrap
   applies and reloads the templated `miserc.toml` before the first macOS-only
   mise task. The guide should still use an explicit `MISE_ENV` during initial
   history adoption and explain that `auto_env = true` is rendered for later
   runs.
5. The selected profile controls tracked-file variants. Work currently tracks
   AWS, Claude, Codex, and Drafthouse configuration; home selects the two Codex
   declarations.
6. Tracked files are not stored in `oppegard/dotfiles`. The current mise origin
   is the separate private `oppegard/setup` repository. A new machine must
   authenticate and adopt that history before relying on tracked files.
7. The current declarations do not enable history encryption. The setup
   repository therefore contains plaintext tracked-file versions and must stay
   private; no age identity is currently required. Encryption would need to be
   configured before the first encrypted save if that policy changes.
8. The current history tree contains `home`'s Codex config but not the declared
   `home` variant of `~/.codex/rules/default.rules`. The guide must identify
   this as a present restore gap rather than promise a complete home restore.
9. Prefer SSH URLs for both the dotfiles checkout and setup-history adoption.
   The checked-in Git config contains a version-specific HTTPS GitHub credential
   helper path that is already stale locally, while SSH uses the restored key
   material directly.
10. On a never-launched BetterDisplay install, `betterdisplay:export` cannot
    export the preference domain or required keys. `setup.sh` launches the app
    only after that export, so the guide needs a first-run preparation or an
    explicit recovery-and-rerun sequence. Importing the repository's portable
    profile is the appropriate restore direction on a new machine.
11. The Brewfile contains a Mac App Store entry for Clocker, so the Mac App
    Store account must be ready before `brew bundle` can restore that entry.
12. After setup, a fresh login shell is required for the new login shell and
    linked shell files to take effect. BetterDisplay, Clocker, SoundSource, and
    other GUI applications may still require first-launch permissions and
    login-item choices.

## Proposed `Bootstrap.me` structure

1. State the supported machine assumptions and what the process changes.
2. Provide a preflight checklist for macOS updates, administrator access,
   Homebrew, Homebrew Bash, App Store sign-in, SSH keys, GitHub access, and the
   exact checkout path.
3. Provide a copyable first-session sequence for installing mise and exporting
   its install directory onto `PATH` without relying on shell activation that
   the repository has not installed yet.
4. Explain `home` versus `work` selection and show how to adopt the private mise
   history repository over SSH before running `setup.sh`.
5. Explain which files come from the dotfiles checkout versus mise history,
   including the lack of encryption and the incomplete home variant.
6. Document the BetterDisplay first-run ordering issue and a safe preparation
   or recovery path that does not overwrite the portable profile with default
   preferences.
7. Show how to run `bin/setup.sh`, what each major phase does, and which phases
   are intentionally repeated after history adoption.
8. List post-setup manual work: open a new login shell, complete application
   permissions and login-item setup, verify the history watcher and origin, and
   inspect dotfile/bootstrap convergence.
9. Add focused troubleshooting for history conflicts, a missing tracked
   variant, BetterDisplay export failure, App Store failure, and GitHub
   authentication failure.
10. Link to current first-party mise and Homebrew documentation used to verify
    the workflow.

## Verification plan

- Cross-check every command against the current `mise 2026.9.x` CLI help and
  current first-party mise documentation.
- Verify every repository path and declaration against `bin/setup.sh`,
  `mise/config.toml`, `mise/config.macos.toml`, and `Brewfile`.
- Keep all investigation and validation read-only; do not adopt, pull, save, or
  apply history and do not apply macOS defaults.
- Run a Markdown formatting check that can target the nonstandard `.me`
  filename, plus `git diff --check`.
- Review the final diff to ensure only `Bootstrap.me` and this approved plan
  changed.

## Checklist

- [x] Inspect setup, mise, Brewfile, shell, BetterDisplay, and Git configuration.
- [x] Inspect current mise profile, history, service, and origin state without
  printing tracked-file contents.
- [x] Verify current upstream mise bootstrap, history-adoption, environment,
  and installation behavior.
- [x] Identify fresh-Mac prerequisites and ordering cycles.
- [x] Obtain approval for this implementation plan.
- [x] Create `Bootstrap.me` at the repository root.
- [x] Validate the guide's commands and Markdown formatting.
- [x] Update this checklist with the completed verification results.

## Verification results

- Isolated mise rendering produced the expected `home` and `work` miserc files.
- Isolated history adoption restored a profile-scoped tracked file from a local
  bare Git origin into separate config/state directories.
- An isolated login-shell dry run planned the `/etc/shells` update before
  `chsh`.
- An empty preference-domain probe confirmed the BetterDisplay missing-key
  failure path without reading or writing BetterDisplay's real domain.
- The current dotfile bootstrap dry run completed with the work profile and
  automatic platform discovery enabled.
- `bash -n bin/setup.sh`, `shellcheck bin/setup.sh`, Markdownlint for both changed
  documents, and `git diff --check` passed.
- The unrelated untracked `CONTEXT.md` was left untouched.
