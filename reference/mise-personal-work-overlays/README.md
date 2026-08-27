# Personal and work dotfiles with Mise

These are three runnable implementations of personal/work configuration
layering, grounded in `reference/mise-dotfiles-advanced-users.md`. Each version
manages the same two examples:

- Codex `~/.codex/config.toml` and native profile files, currently supplied by
  Stow in this repository;
- Git identity `~/.config/git/identity`, alongside the common Git files already
  supplied by Mise.

The examples deliberately manage individual files inside `~/.codex` and
`~/.config/git`. Both directories contain local or runtime state, so whole-tree
ownership and broad `symlink-each` traversal would be too aggressive.

Run all examples without touching your real home:

```sh
./reference/mise-personal-work-overlays/test.sh
```

## Recommendation

Use **01: explicit environments** for the production migration. Keep personal
configuration as the default and select work deliberately:

```sh
mise -C mise bootstrap dotfiles apply
mise -C mise -E work bootstrap dotfiles apply
```

More specifically:

- migrate Codex from Stow as explicit per-file entries; keep the personal
  defaults in `config.toml`, deploy a private `work.config.toml` overlay only
  on work machines, and launch it with `codex --profile work`;
- make Git identity the second example: keep common Git behavior in the
  existing `mise-dots/gitconfig`, but move identity into a small profile-owned
  file included by that common config;
- keep secrets and employer-only policy in the private `dotfiles-work` repo;
- have `bin/setup.sh` select `-E work` only when that private repo is present.

This follows the research synthesis directly: config layers answer “which
targets exist on this machine?”, while templates are reserved for content that
genuinely varies within one target.

## Comparison

| Version | Concept | Advantages | Costs |
| --- | --- | --- | --- |
| [01 explicit environments](01-explicit-environments/) | `mise.toml` supplies personal defaults; `mise.work.toml` deploys Codex's native work overlay and overrides Git identity | Selection is visible, the Codex work file layers over personal defaults, work-only targets can be absent, and private sources remain separate | Setup must consistently pass `-E work`, and Codex work sessions must use `--profile work`; switching a machine back should unapply work-only targets |
| [02 local overlay](02-local-overlay/) | A gitignored `mise.local.toml` overrides target sources on one machine | Normal bootstrap needs no profile flag and the local choice can contain private paths | Important desired state is hidden and unversioned; onboarding needs a copy/edit step; stale local files are easy to forget |
| [03 profile templates](03-profile-templates/) | Environment files set `vars.profile`; Mise renders common templates | Avoids duplicated files and works well for a few scalar differences | Personal and work concerns become interleaved, rendered copies can drift, and templates are awkward for large Codex files or private work policy |

## Why Git identity is the best second example

Git already has a clean separation between shared behavior and identity. The
existing `mise-dots/gitconfig` contains aliases, pull/rebase behavior, hooks,
and signing defaults, while `~/.config/git/local` is already included. A small
profile-owned identity file makes the work override obvious and independently
testable without duplicating the large common config.

For a laptop that mixes personal and work repositories at the same time,
Git's native conditional include remains better than a machine-wide profile:

```gitconfig
[includeIf "gitdir:~/src/work/"]
	path = ~/.config/git/identity.work
```

Mise should distribute `identity.work`; Git should decide when to use it. That
is an application-level exception to the recommended machine profile, not a
reason to make every application's overlay conditional.

## Production notes

- The examples use fake names, addresses, and keys. No work secret or real
  employer policy belongs on this public branch.
- Codex officially supports `$CODEX_HOME/<profile>.config.toml` files selected
  by `--profile`; use that native composition rather than inventing a merge
  format. Do not put the legacy `profile = "work"` selector in `config.toml`.
  See the [official Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).
- Codex's directory also contains sessions, caches, plugins, and credentials.
  Manage named files only.
- Prefer symlinks for hand-edited source files. Use `copy` or `template` only
  when the target must be independently writable or rendered.
- A production change should apply twice and then require
  `mise bootstrap dotfiles status --missing` to pass, as these tests do.
