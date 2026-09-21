# Minimal `dotf run` bootstrap

Approved 2026-09-21. Install Homebrew, Homebrew Bash, and mise when missing,
verify them, and stop without executing `setup.sh`. Follow Nate's small shell
entrypoint, separate bootstrap, and shared-helper layout.

## Implementation checklist

- [x] Save the approved plan before coding, without overwriting an existing file.
- [x] Add executable `bin/dotf`: `/bin/bash`, symlink-aware discovery, `main()`,
  `cmd_run()`, help aliases, and rejection of unknown commands/extra arguments.
- [x] Add executable `bin/bootstrap`: require Apple Silicon macOS; discover
  Homebrew at `/opt/homebrew/bin/brew` even outside PATH; conditionally install
  Homebrew, `/opt/homebrew/bin/bash`, and mise using official installers.
  Discover mise through `~/.local/bin` and PATH. Preserve installer prompts and
  stop on download, installation, or verification failures.
- [x] Add `bin/lib/dotf-common.sh` with environment helpers and Gum/plain-text
  announcements. After bootstrap, refresh Homebrew then mise in the parent
  script and verify all three executables.
- [x] Update `BOOTSTRAP.md` after cloning to use the new command instead of
  manual Homebrew/Bash/mise installation.

## Completion behavior and boundaries

Print "Tool prerequisites installed" and these commands for the calling shell:

```sh
eval "$(/opt/homebrew/bin/brew shellenv bash)"
export PATH="$HOME/.local/bin:$PATH"
export MISE_AUTO_ENV=true
```

Explain that the subprocess cannot update its parent shell. Direct the user to
profile selection, private-history adoption, Git identity, and BetterDisplay
preparation before Step 11. Leave Apple tools, cloning, credentials, and GUI
preparation manual. Keep `setup.sh`, Brewfile, and mise declarations unchanged:
Bash is already declared but needed before mise configures the login shell.
Retain existing installations without version pinning or upgrades.

Installer references: [Homebrew](https://docs.brew.sh/Installation) and
[mise](https://mise.jdx.dev/installing-mise.html).

## Validation checklist

- [x] Bash syntax checks, ShellCheck, Markdownlint, and `git diff --check`.
- [x] Isolated stubs: missing tools, existing tools outside PATH, repeat runs,
  installer/download/verification failures, and unsupported hosts.
- [x] Confirm help installs nothing and run never invokes setup/mise bootstrap.
- [x] Preserve unrelated changes; record that real installers and a fresh-Mac
  run remain untested.

## Validation results

Implemented 2026-09-21. Bash 3.2 syntax checks, ShellCheck, Markdownlint,
and whitespace checks passed.
Isolated command stubs passed for help/argument handling, unsupported hosts,
fresh installation, tools outside PATH, reuse of PATH-provided mise, repeat
runs, relative symlink invocation, and download, installer, Bash install, mise
install, shellenv, and version-verification failures. The isolated fixture
redirected the fixed Homebrew prefix into a temporary directory.

No real installers, setup, mise bootstrap, private history, or machine settings
were exercised. A fresh-Mac run remains untested. Unrelated files were preserved.
