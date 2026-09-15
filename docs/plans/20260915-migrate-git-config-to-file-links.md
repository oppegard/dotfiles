# Migrate Git config to per-file mise links

## Goal

Make `~/.config/git` a real directory. Link only intentionally managed files
from `mise-dots/config/git`; keep machine-local config and Git-generated hooks
in the live directory, outside the repository.

## Current state

- `mise/config.toml` maps all of `~/.config/git` to
  `mise-dots/config/git` using the default `symlink` mode.
- The tracked source files are `ignore`, `local.example`, and
  `hooks/pre-commit`. The source also contains ignored `local` and four
  untracked Git LFS hooks (`post-checkout`, `post-commit`, `post-merge`, and
  `pre-push`) because the live directory is a link into the repository.
- `~/.gitconfig` reads `~/.config/git/local`, uses
  `~/.config/git/ignore`, and sets `core.hooksPath` to
  `~/.config/git/hooks`. Those paths must keep working through the transition.

## Proposed changes

1. Replace the single-directory mapping with:

   ```toml
   "~/.config/git" = { source = "~/.dotfiles/mise-dots/config/git", mode = "symlink-each", manifest = "git" }
   ```

   `manifest = "git"` limits links to files in Git's index. It links the
   tracked `ignore`, `local.example`, and `hooks/pre-commit`, while leaving
   `local` and Git LFS-generated hooks unmanaged. Keep the existing
   `.gitignore` rule for the source-side `local` file as a safeguard.

2. Add `bin/migrate-git-config-to-file-links` as a repeatable, interactive
   wizard using the local `wizard` template without editing its library.
   The proposed stages are: preflight, inventory and private backup,
   confirmed cutover and targeted mise apply, and verification. No values
   are captured or written to external services. The wizard must work after
   the new mapping has been pulled, when the old declaration is no longer
   available to `mise unapply`. It will verify an existing directory symlink
   points to this checkout's source, move only ignored or untracked files,
   and refuse conflicting live files. Offer a `--dry-run` preview.

3. Edit `mise/config.toml`. The script will preview and apply only
   `~/.config/git` with mise. It will not use `--force`. Confirm that managed
   files become individual links and machine-only files remain regular live
   files. Re-running it should be safe after a successful migration.

4. Verify the Git include, global excludes, and hook path still resolve;
   compare preserved machine-only files with the backup without printing
   their contents. Validate the wizard statically with ShellCheck and
   `bash -n`, without running its interactive stages end-to-end. Exercise
   mise's Git manifest in an isolated temporary target, then validate TOML
   and check the Git diff and worktree status. Document the new ownership
   model and invocation in the README.

## Reasoning

The directory link makes application-written files appear in the repository.
Per-file links make the ownership boundary explicit without changing Git's
configured paths. The Git manifest also prevents a future untracked hook or
machine-local file in the source tree from being deployed as a managed link.
On a second machine, the new configuration may arrive before its live
directory link changes. The script therefore verifies and replaces the exact
old symlink itself rather than depending on the old declaration still being
loaded by mise. A private backup and conflict checks protect machine-only
files through the transition.

## Checklist

- [x] Inspect the current mapping, tracked source files, and live directory.
- [x] Check current mise `symlink-each`, Git manifest, and unapply behavior.
- [x] Receive the request to implement this as a script for another machine.
- [x] Scope the wizard stages and identify that no values are captured.
- [x] Confirm the wizard stage order with the user.
- [x] Copy the wizard template and author its stages below the marker.
- [x] Implement dry-run, backup, verified link replacement, and file moves.
- [x] Change the mise mapping and update the README invocation and ownership.
- [x] Preview and apply only the new `~/.config/git` mapping in the wizard.
- [x] Validate wizard wiring statically and exercise mise in an isolated target.
- [x] Run ShellCheck, validate TOML, and check the diff.
