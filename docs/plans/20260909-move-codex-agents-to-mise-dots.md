# Move Codex AGENTS.md to mise-dots

## Goal

Make mise, rather than stow, own the user-level Codex instructions at
`~/.codex/AGENTS.md`.

## Proposed changes

1. Move the existing canonical instruction file from
   `stow/codex/dot-codex/AGENTS.md` to `mise-dots/codex/AGENTS.md`, preserving
   its contents.
2. Add a `[dotfiles]` entry in `mise/config.toml` mapping
   `~/.codex/AGENTS.md` to that new source. The configuration's existing
   `dotfiles.default_mode = "symlink"` will make the target a symlink.
3. Remove the old stow-managed source so there is exactly one owner for the
   target.
4. Validate TOML formatting and the resulting diff; do not run a stateful
   mise bootstrap against the user's home directory.

## Reasoning

The instructions currently live in the stow tree, while the rest of the
requested ownership model is mise's declarative `[dotfiles]` configuration.
Moving the source and declaring the target in mise keeps the source in the
repository and makes its deployment method explicit without changing the
instructions themselves.

## Checklist

- [x] Move the instruction source into `mise-dots/codex/`.
- [x] Declare the Codex target in `mise/config.toml`.
- [x] Remove the obsolete stow source.
- [x] Validate configuration syntax, apply the targeted symlink, and inspect
  the diff.
