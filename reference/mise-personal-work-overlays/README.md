# Personal and work dotfiles with Mise

These are three runnable implementations of personal/work configuration
layering, grounded in `reference/mise-dotfiles-advanced-users.md`. Each version
manages the same two examples:

- Codex in the ChatGPT desktop app, using `~/.codex/config.toml`, currently
  supplied by Stow in this repository;
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

- migrate Codex from Stow as one explicit `~/.codex/config.toml` entry; keep
  the personal source as the default and have the work Mise environment
  replace that source with the complete private work configuration;
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
| [01 explicit environments](01-explicit-environments/) | `mise.toml` supplies personal sources; `mise.work.toml` replaces the Codex and Git identity sources | Selection is visible and versioned, ChatGPT reads the selected canonical Codex file without launch flags, and private sources remain separate | Setup must consistently pass `-E work`; the two complete Codex files may duplicate shared settings |
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
- For the ChatGPT desktop app, keep the effective configuration at the
  user-level `~/.codex/config.toml`. Codex profile files require a CLI
  `--profile` choice, so they do not satisfy this desktop-app use case. See
  [official config basics](https://learn.chatgpt.com/docs/config-file/config-basic),
  the [config reference](https://learn.chatgpt.com/docs/config-file/config-reference),
  and the [current ChatGPT overview](https://learn.chatgpt.com/).
- Codex's directory also contains sessions, caches, plugins, and credentials.
  Manage named files only.
- Prefer symlinks for hand-edited source files. Use `copy` or `template` only
  when the target must be independently writable or rendered.
- A production change should apply twice and then require
  `mise bootstrap dotfiles status --missing` to pass, as these tests do.
