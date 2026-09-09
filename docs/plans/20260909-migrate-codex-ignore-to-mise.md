# Migrate Codex ignore file to mise

## Goal

Make mise own `~/.codex/.ignore` instead of stow.

## Proposed changes

1. Move the existing ignore-file source from `stow/codex/dot-codex/.ignore`
   to `mise-dots/codex/.ignore` without changing its rules.
2. Add a `[dotfiles]` entry mapping `~/.codex/.ignore` to the new source.
   The existing `dotfiles.default_mode = "symlink"` will create the symlink.
3. Remove the obsolete stow source, then use mise to apply only the Codex
   ignore-file target.
4. Verify the source content, resolved live link, TOML parsing, and diff.

## Reasoning

The Codex instruction file was moved to mise ownership. Moving this adjacent
Codex-managed file with the same mechanism eliminates the remaining split
between stow and mise for these user-level Codex files.

## Checklist

- [x] Move the ignore source into `mise-dots/codex/`.
- [x] Declare the ignore target in `mise/config.toml`.
- [x] Remove the obsolete stow source.
- [x] Apply and verify the targeted mise symlink.
