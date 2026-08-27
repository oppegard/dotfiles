# Mise personal/work overlays

## Goal

Prototype three reviewable ways to manage personal and work variants with
Mise native dotfiles. Exercise two real configurations from this repository:
Codex, which is still managed by Stow, and Git identity, whose common files
are already managed by Mise.

## Design

The alternatives are isolated examples and do not alter the live bootstrap.
Each uses a temporary `HOME` in its test so applying an example cannot replace
the reviewer's real Codex or Git configuration.

1. Explicit Mise environments: a shared config defaults to personal sources,
   while `mise.work.toml` overrides only profile-owned targets.
2. Machine-local overlay: a gitignored `mise.local.toml` selects sources for
   one machine without requiring `-E work` on every invocation.
3. Profile-driven templates: one target map renders personal or work content
   from a profile variable.

The comparison will select one production direction and explain why the other
two remain useful patterns rather than interchangeable solutions.

## Checklist

- [x] Inventory existing Mise, Stow, Codex, and Git configuration.
- [x] Extract constraints from `reference/mise-dotfiles-advanced-users.md`.
- [x] Implement the three isolated examples.
- [x] Test personal and work application for every example.
- [x] Test a second apply and `status --missing` for convergence.
- [x] Document mechanics, tradeoffs, and a recommendation.
- [x] Commit and push the review branch.
