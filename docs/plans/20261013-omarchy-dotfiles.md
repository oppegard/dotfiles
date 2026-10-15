# Linux dotfiles bankruptcy and Omarchy coexistence

Status: Linux cleanup implemented in this PR. Shared-config integration below is
planned follow-up work; this PR does not make the full bootstrap Omarchy-safe.

## Ownership

Omarchy owns the Linux desktop, session environment, terminal appearance, and
its default shell integrations. This repository should add portable personal
preferences without replacing Omarchy's config directories or copying its
packaged defaults. macOS keeps its current behavior.

The cleanup removes Hyprland (including scripts and backups), keyd application
mapping, UWSM, Walker, Waybar, old branding, the Linux Screen and Try binaries,
and the Linux desktop-entry shell helper. The Linux Sublime Text link is also
retired; its source files remain because macOS uses them. Generic Linux Bash
and Git package prerequisites remain for bootstrap and Ubuntu CI.

The one retained Linux customization is the unchanged
`files/home/.config/omarchy/branding/screensaver-lappy386.txt`. The Linux manifest
links that file directly to `~/.config/omarchy/branding/screensaver.txt` rather
than taking ownership of `~/.config/omarchy`. Omarchy supplies the animation,
launching, idle settings, and all other branding.

## Follow-up 1: separate config ownership before bootstrapping Omarchy

Audit every entry in `files/home/.config/mise/config.toml` against a fresh
Omarchy installation. Linux alone is not a sufficient signal for Omarchy:
Ubuntu integration runners still need a working generic Linux setup. Introduce
an explicit, opt-in Omarchy profile or equivalent supported mise condition;
verify profile composition with `home` and `work` before choosing the mechanism.

| Config | Omarchy policy |
| --- | --- |
| `.bashrc`, `.bash_profile` | Keep Omarchy's startup files; add a small personal source hook. |
| `.inputrc` | Keep Omarchy's Readline setup; add only individually reviewed bindings. |
| `.config/shell` | Install personal fragments under a repo-specific path, avoiding generic `local` names. |
| Ghostty, btop, Starship | Keep Omarchy's configs and theme includes; scope existing personal replacements to macOS unless explicitly opted into. |
| Git | Keep portable personal settings; inspect credential helpers, signing, SSH socket paths, and host-local includes on Linux. |
| `.ssh/config` | Review before replacing: retain host-local includes and existing Omarchy/1Password authentication setup. |
| curl, ripgrep, uv, tmux, Screen, npm, Bun | Check dependencies and collisions, then allow individual files where portable. |
| `.local/bin`, mise tools and services | Audit names and versions against installed Omarchy commands; avoid duplicate history services and unnecessary package upgrades. |

Keep the common manifest small. Move platform-specific replacements to the
platform manifest and keep Omarchy-specific additions explicit. Do not delete
portable shared configs just because Linux consumes them. Review existing
Linux-targeted links after each move; removing a declaration is not evidence
that its installed symlink has been removed.

## Follow-up 2: make shell preferences additive

1. Preserve the installed Omarchy Bash startup sequence and environment
   bootstrap, including its noninteractive behavior. Add one guarded source
   line after its interactive defaults to load a personal fragment. Manage
   that insertion idempotently, with a backup and a preview; do not symlink
   `.bashrc` or `.bash_profile` on Omarchy. Keep the current macOS startup files.
2. Split personal aliases, functions, and exports from `shell/all` and
   `shell/inits`. The Omarchy entry point should load personal preferences only,
   without rerunning the shared initializer. Omarchy already initializes mise,
   Starship, zoxide, fzf, Try, and Bash completion. Choose one owner per tool;
   retain the standalone initializer for macOS and generic Linux.
3. Resolve deliberate overlaps: `tdl` and `EDITOR` already exist in the installed
   Omarchy defaults. Rename personal helpers when appropriate; make any override
   explicit. Add PATH entries only once. Keep Homebrew and OrbStack logic on
   macOS and guard optional commands and completion files by availability.
4. Preserve Omarchy's history and prompt hooks. If retaining personal live Bash
   history synchronization, register it once, preserve existing scalar or array
   `PROMPT_COMMAND`, and check interaction with mise history watching. Do not
   activate mise in both the session environment and Bash startup.
5. Keep macOS Git completion behavior covered by the existing integration test.
   Add isolated startup checks for Omarchy: interactive login/non-login shells,
   SSH/noninteractive shells, missing optional tools, and repeated sourcing.
   Check Git and mise completion with actual Tab input and ensure each tool
   initializer and prompt hook runs once.

## Follow-up 3: migrate an existing machine deliberately

This PR changes repository sources and declarations. It does not reset the live
machine, uninstall packages, disable services, or automatically undo old links.
The shared manifest still replaces shell, terminal, prompt, and other files;
**do not run the full `dotf run` or `setup.sh` on Omarchy until the ownership work
above is complete.**

Before switching an existing machine to this commit:

1. Keep a terminal open and back up the live configs, dereferencing old repo
   symlinks while their sources still exist. Record the previous Git commit.
   Old sources can also be recovered from Git history after the cleanup.
2. Inspect `readlink` for `~/.config/{hypr,keyd,omarchy,uwsm,walker,waybar}`,
   the retired Linux Sublime Text target, and `~/.local/bin/{screen,try}`.
   Remove only links that point into the retired repo paths. Never recursively
   delete a real config directory. In particular, detach the old whole-directory
   Omarchy link before installing the individual screensaver link, or the new
   file could be written into the checkout instead of the user's config.
3. Restore stock desktop/session config using the installed Omarchy version's
   documented refresh commands, after reviewing their scope and backups. This
   is a separate, confirmed machine operation, not part of applying this PR.
   Review any old keyd mapper/autostart/service setup separately.
4. Preview the new dotfile declarations with `mise bootstrap --dry-run` from the
   config directory. Apply only the reviewed screensaver mapping initially,
   using an isolated manifest if needed so shared mappings cannot overwrite
   Omarchy's files. Confirm it resolves to lappy386 and preview the screensaver.
5. After follow-ups 1 and 2, apply the reviewed shared additions twice. Check
   that a second application makes no changes, Omarchy updates still work,
   theme switches update the terminal and btop, and stock keybindings, launcher,
   lock, and idle behavior remain available. Compare backups before removal.

## Validation

For the cleanup, verify the lappy386 bytes are unchanged, every remaining
manifest source exists, and no active reference targets deleted Linux files.
Run `mise run lint` and `mise run test:integration`; the local suite intentionally
skips machine-changing bootstrap unless on a disposable runner. macOS and Linux
CI provide the two real bootstrap passes. Test actual Omarchy coexistence in a
fresh Omarchy VM in the follow-up, since Ubuntu CI cannot establish that.

## Sources and version caveat

The installed Omarchy source inspected during planning reports `4.0.0.alpha`
and lives under `/usr/share/omarchy`. Its `default/bashrc`, `default/bash/rc`,
`default/bash/{envs,shell,init}`, and `bin/omarchy-screensaver` establish the
startup sequence, tool initialization, and artwork path described above.
Recheck the target machine's installed sources before implementing the plan;
older Omarchy versions use different paths and desktop components.

- [Omarchy dotfiles guidance](https://github.com/omacom/omarchy/blob/quattro/manual/31-dotfiles.md)
- [Omarchy branding and screensaver path](https://github.com/omacom/omarchy/blob/quattro/manual/41-branding.md)
- [Omarchy configuration layout](https://github.com/omacom/omarchy/blob/quattro/docs/file-layout.md)
