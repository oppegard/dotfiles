# Migrate mise dotfile sources to `files/home`

Status: Compatibility implementation complete; awaiting human Mac cutover.

## Objective

Move every declarative dotfile source currently rooted at
`~/.dotfiles/mise-dots/` into a filesystem-shaped
`~/.dotfiles/files/home/` layout without changing any `[dotfiles]` target
(the left-hand side of each mapping), losing machine-local files, or leaving
live links pointed at the retired tree.

Use a confirmation-gated migration wizard for the live cutover. Keep the old
and new source trees identical during a compatibility window, migrate each
machine, and remove `mise-dots/` only after the affected macOS and Linux hosts
have passed verification.

## Current-state evidence

- The three mise TOML files contain 39 affected `[dotfiles]` mappings:
  21 shared mappings, 9 macOS mappings, and 9 Linux mappings. A fortieth
  `mise-dots/` reference is the macOS unsupported-defaults task manifest, not
  a dotfile mapping.
- On the current Mac, mise 2026.9.10 reports all 30 active affected mappings
  as `applied`: 26 whole-path symlinks, 3 `symlink-each` mappings, and 1 copy.
- The live `symlink-each` roots contain state that must remain outside Git:
  - `~/.config/git/local` and four Git LFS-generated hooks are regular files;
  - `~/.local/bin/idea`, `idea-prev`, `mise`, and `tuna` are regular files;
  - `~/.config/shell` currently contains only the five managed links.
- `~/.config/sublime-text/Packages/User` is a macOS leftover link to the old
  shared Sublime source. It is not part of the currently selected macOS
  mapping; the active target is under `~/Library/Application Support/`.
- No affected live link is currently dangling, so the migration can preserve
  a clean starting point.
- `mise-dots/` contains 82 tracked files. Two are support assets rather than
  home-file sources: `BetterDisplay.plist` and
  `unsupported-defaults.json`.
- The current Git-config migration wizard hard-codes
  `mise-dots/config/git`; the full-layout wizard must absorb its preservation
  logic before that path is retired.
- The worktree already contains unrelated untracked work. Implementation must
  leave it untouched and must not require the whole worktree to be clean.

## Design decisions

### Preserve the existing ownership boundary

Keep every `[dotfiles]` key and mode unchanged. This adopts the useful part of
the Nate Berkopec layout--sources mirror home-relative paths under
`files/home/`--without adopting its broad
`"~" = { source = "~/.dotfiles/files/home", mode = "copy" }` mapping. A
whole-home copy would broaden this repository's ownership and violate the
requirement that the left-hand targets remain unchanged.

The separate `oppegard/setup` repository is mise's tracked-history origin.
Its `home@home` and `home@work` directories confirm that profile variants
belong to tracked state; they do not need to be folded into this declarative
source relocation.

### Final source layout

Apply the direct target-relative rule wherever one source has one target. For
example:

```toml
"~/.config/btop" = "~/.dotfiles/files/home/.config/btop"
"~/.digrc" = "~/.dotfiles/files/home/.digrc"
```

Use these explicit exceptions:

1. Keep the shared Sublime source canonical at
   `files/home/.config/sublime-text/Packages/User`. Both existing macOS and
   Linux targets continue to point to it, avoiding duplicated settings.
2. Put common and platform-specific executables in
   `files/home/.local/bin`. Preserve the shared `~/.local/bin`
   `symlink-each` mapping, but exclude:
   `fix-tahoe-focus`, `flush-dns`, `restart-soundsource`,
   `screen-5.0.1`, `try-darwin-aarch64`, and `try-linux-x86_64`.
   The existing OS-specific mappings continue to publish the appropriate file
   under its unchanged live name (`screen` or `try`).
3. Keep the macOS and Linux TOML layers. Do not replace them with templates or
   a new variant abstraction as part of this migration.
4. Move the two non-home support assets to `files/macos/`, then update
   `bin/betterdisplay-prefs`, the unsupported-defaults task, and active
   documentation. Keeping these assets outside `files/home/` avoids implying
   that a future whole-home mapping should install them verbatim.
5. Leave `~/.dotfiles = ~/src/dotfiles`, mise's own config-file mappings, and
   all `mode = "track"` entries unchanged.

### Compatibility window

Land the migration in two phases:

1. Add the new source tree, switch the TOML declarations to it, and add the
   wizard while retaining byte-identical old sources temporarily. Existing
   links remain valid before the wizard runs, including on another machine
   that pulls the change.
2. After the wizard has migrated and verified each affected macOS/Linux host,
   remove the old tracked tree and its active references. This temporary
   duplication is deliberate; the completed migration must contain no old
   source copies.

Do not depend on `mise dotfiles unapply`: once the declaration selects the new
source, unapply no longer describes the old link graph. Current mise
documentation says apply can repoint existing symlinks and that
`symlink-each` preserves unmanaged neighbours, but isolated fixtures must prove
the exact source-change behavior before a live cutover.

## Wizard specification

Add a committed, cross-machine wizard at
`bin/migrate-mise-dots-to-files-home`. It is repeatable migration tooling for
the compatibility window, not a permanent setup dependency. Base it on the
unchanged wizard template library and support `--dry-run`.

The wizard captures no secrets and writes no `.env` or remote values. Its only
generated value is a mode-0700 private backup directory under
`${TMPDIR:-/tmp}`, which it prints throughout the run and in the final summary.

### Stage 1: Check this checkout and classify the machine

- Resolve the wizard's checkout and require `~/.dotfiles` to point to it.
- Detect macOS or Linux and verify that the corresponding mise layer is
  loaded.
- Verify the exact old/new mapping manifest, modes, executable bits, and
  content equality during the compatibility phase.
- Classify each live target as old link, new link, copy, missing, legacy Git
  directory link, or unexpected conflict. Refuse unexpected targets.
- Check only the migration-owned paths for tracked worktree changes; report
  but do not disturb unrelated changes.

Output: an in-memory migration manifest and a read-only preflight report.

### Stage 2: Inventory and make a private recovery backup

- Back up the affected live targets with symlink metadata and permissions.
- Back up regular/unmanaged neighbours in the three `symlink-each` roots.
- Back up the Rectangle Pro copy target and any machine-only files left under
  an old legacy Git-config source directory.
- Record checksums, file modes, old link destinations, and the known stale
  Sublime link.
- Stop on sockets, devices, unexpected source files, or destination
  conflicts.

Output: the private backup path plus before-state manifests/checksums. No
secret or public value is captured.

### Stage 3: Confirm and apply the new sources

- Show the exact targets that will change and require an explicit `y/N`
  confirmation.
- If a machine still has the legacy whole-directory Git link, convert it to a
  real directory and restore its machine-only files using the guarded logic
  from `bin/migrate-git-config-to-file-links`.
- Preview and then apply only the active affected dotfile targets with mise.
- Never pass `--force`; an unexpected real file or directory is a stop
  condition, not permission to overwrite it.
- On failure, retain the backup and restore the pre-cutover links/copy from
  the recorded manifest while the old sources still exist.

Output: repointed live mappings or a restored pre-cutover state.

### Stage 4: Reconcile known leftovers

- On macOS, move the verified stale
  `~/.config/sublime-text/Packages/User` link into the private backup, then
  prune only empty parent directories.
- Scan the affected home roots for links whose destination still contains
  `/mise-dots/`.
- Move only recognized stale links into the backup. Stop and report any
  unexpected old-source link rather than deleting it.
- Verify that machine-owned regular files remain regular and unchanged.

Output: no recognized stray live links, with every removed link recoverable
from the backup.

### Stage 5: Verify convergence

- Require every active affected entry in
  `mise bootstrap dotfiles status --json` to be `applied` and to resolve under
  `files/home`; separately verify that the two support consumers resolve under
  `files/macos`.
- Run a second targeted dry-run and require no planned changes.
- Re-scan for old-source and dangling links under the affected roots.
- Compare saved checksums/modes for unmanaged neighbours and the copy target.
- Print the backup path, host/platform, target counts, and whether repository
  cleanup is now eligible.

Output: a human-readable verification summary. The wizard does not commit,
push, merge, or remove the compatibility tree.

## Implementation sequence

1. Build a machine-readable old-source-to-new-source manifest from the 39
   mappings and use it in both migration tests and wizard validation.
2. Copy the tracked sources into `files/home/` (and the two support assets into
   `files/macos/`) while preserving contents and executable modes. Prove every
   old/new pair is identical before changing a declaration.
3. Update only the right-hand source side of the existing dotfile mappings;
   add the narrow `.local/bin` exclusion list without changing its target or
   mode.
4. Update active consumers and documentation, including BetterDisplay,
   unsupported defaults, Git-config migration guidance, and setup guidance.
   Preserve historical plan text unless it is an active instruction. Do not
   edit unrelated untracked documents without explicit confirmation.
5. Add the five-stage wizard and fold in the legacy Git-directory handling.
   Retire or replace `bin/migrate-git-config-to-file-links` only after its
   supported old states are covered by the new wizard.
6. Add isolated macOS and Linux fixtures that exercise whole symlinks,
   `symlink-each`, `manifest = "git"`, copy mode, platform-only executables,
   the shared Sublime source, stale links, machine-owned neighbours, and a
   second idempotent apply.
7. Run the wizard in `--dry-run` mode on the current Mac. Do not run the
   interactive cutover from an agent session; hand it to the user with the
   backup and rollback expectations stated explicitly.
8. After the current Mac succeeds, repeat on the Linux host. If that host is
   unavailable, keep the compatibility tree; isolated Linux tests alone do not
   authorize final cleanup.
9. Once all hosts report no links to `mise-dots/`, remove the old tracked
   sources, obsolete compatibility code, and active old-path references.
10. Re-run repository and live-state verification, then update this checklist
    with evidence.

## Verification

Repository/static checks:

- `bash -n bin/migrate-mise-dots-to-files-home`
- `shellcheck bin/migrate-mise-dots-to-files-home`
- verify the wizard library above `STAGES` is byte-identical to
  `/Users/glenn/.agents/skills/wizard/template.sh`
- `tombi lint mise/config.toml mise/config.macos.toml mise/config.linux.toml`
- `mise fmt --check`
- `git diff --check`
- compare old/new tracked file contents and executable modes from the manifest
- assert all 39 `[dotfiles]` keys and modes are unchanged
- assert no active source or script reference uses `mise-dots/` after cleanup
- assert `git ls-files 'mise-dots/**'` is empty after the final phase

Isolated behavior checks:

- apply the macOS fixture twice, then require dotfile status to be clean;
- apply the Linux fixture twice, then require dotfile status to be clean;
- prove platform-only `.local/bin` sources do not leak onto the other OS;
- prove Git and shell `symlink-each` mappings preserve unmanaged neighbours;
- prove the Git manifest ignores untracked source files;
- prove copy mode keeps the Rectangle target identical;
- prove both an already-migrated host and an old/dangling-link host converge.

Live checks after the human runs the wizard:

- all active affected entries are `applied` with new resolved sources;
- a second targeted apply is a no-op;
- no affected symlink points into `mise-dots/` and none is dangling;
- the known stale macOS Sublime link is absent or recoverably backed up;
- Git local config/LFS hooks and unmanaged `~/.local/bin` files retain their
  pre-cutover type, mode, and checksum;
- `betterdisplay:check` and the unsupported-defaults audit still find their
  moved support files without applying preferences.

## Implementation evidence

On 2026-09-18, the compatibility phase completed without changing live
dotfiles:

- all 82 tracked files under `mise-dots/` have byte- and mode-identical
  compatibility copies under `files/home/` or `files/macos/`;
- the 39 dotfile mappings retain their existing target keys and modes while
  selecting the new source paths;
- Bash syntax, ShellCheck, Tombi lint, `git diff --check`, and the unchanged
  wizard-template library check pass;
- the isolated macOS and Linux fixture applies pass twice and preserve
  unmanaged neighbours, Git manifest behavior, copy mode, shared Sublime
  settings, and platform-specific executables;
- `betterdisplay:check` and `macos-defaults:unsupported:check` pass using the
  moved support assets; and
- the full wizard dry-run passes against the current Mac and classifies all 30
  active mappings without modifying them.

The existing TOML style is not Tombi's canonical formatter output, so the
verification uses `tombi lint` rather than accepting unrelated whole-file
formatting changes. The interactive wizard and live Linux run remain human
cutover gates, so `mise-dots/` must remain until both hosts pass Stage 5.

## Rollback boundary

Before final cleanup, rollback is fully local: restore the saved targets from
the private backup and repoint them to the still-present old sources. Do not
use a broad `mise unapply` or `--force`.

After `mise-dots/` is removed, rollback requires restoring the previous Git
revision of the source tree and TOML declarations before restoring the saved
live targets. The cleanup phase must not start until every known host has
passed the wizard's Stage 5 checks.

## Checklist

- [x] Inventory affected declarations, source files, live modes, and current
  macOS state.
- [x] Compare the Nate Berkopec home-mirror layout and the mise tracked-history
  repository.
- [x] Define a macOS/Linux layout that preserves all existing destination
  keys.
- [x] Review and approve this plan.
- [x] Add the compatibility source tree and update declarations.
- [x] Add and statically verify the migration wizard.
- [x] Pass isolated macOS and Linux migration/convergence tests.
- [x] Run the wizard dry-run on the current Mac.
- [ ] Have the user run the confirmed Mac cutover and record verification.
- [ ] Run and verify the cutover on the Linux host.
- [ ] Remove `mise-dots/` and active compatibility references.
- [ ] Pass final repository and live-state checks.
