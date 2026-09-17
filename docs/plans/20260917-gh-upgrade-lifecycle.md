# Make mise-managed gh upgrades safe

## Goal

Keep GitHub's Git credential helper valid across `mise upgrade gh` without
pinning it to a disposable mise installation directory. Make every new `gh`
installation fail visibly if the checked-in helper or mise resolver is unsafe.

## Current state

- `mise/config.toml` selects `gh = "2"` without a tool-level lifecycle hook.
- `mise-dots/gitconfig` now uses a stable, quiet `mise exec` credential helper
  for GitHub and Gist instead of a version-specific `gh` executable.
- `~/.gitconfig` is a managed symlink to `mise-dots/gitconfig`, so the checked-in
  file is the declarative source of truth and installation hooks must not
  rewrite it.
- The history watcher has a separate stale-process condition. Restarting it is
  outside this change because it does not determine how Git resolves `gh`.

## Proposed changes

1. Add a warning comment to `mise-dots/gitconfig` explaining why
   `gh auth setup-git` must not replace the stable helper, with a link to the
   GitHub CLI source that writes the resolved executable path.
2. Add `bin/check-gh-credential-helper`, a read-only checker that:
   - requires the stable helper for both `github.com` and `gist.github.com`;
   - rejects version-pinned mise installation paths;
   - compares the just-installed `gh` version with the version selected through
     the stable `mise exec --quiet gh` resolver;
   - never requests, captures, or prints GitHub credentials.
3. Change the `gh` declaration in `mise/config.toml` to retain version request
   `2` and run the checker as its tool-level `postinstall` command.
4. Add `test/gh-credential-helper_test.sh`. Treat the checker executable as the
   public seam, and use temporary Git configuration plus boundary stubs for
   `gh` and `mise` to cover accepted stable configuration, pinned-helper
   rejection, and resolver-version mismatch.
5. Validate with the test, `shellcheck`, `bash -n`, `mise fmt --check`, a
   read-only checker run against the live configuration, and `git diff --check`.

## Reasoning

The checked-in Git configuration should own the helper value. Rewriting that
file from a postinstall hook would introduce hidden repository mutations and
could damage the managed `~/.gitconfig` symlink. A read-only postinstall check
instead makes `mise upgrade gh` visibly fail when the invariant is broken.

The helper resolves `gh` at credential-use time, so the history watcher does
not need a restart after a `gh` upgrade. Disabling exec-time auto-install keeps
a Git operation from installing tools, while `--quiet` protects Git's
credential protocol from mise diagnostics.

The postinstall command reaches the checker through `$HOME/.dotfiles`, matching
`settings.dotfiles.root`. A full bootstrap applies dotfiles before versioned
tools, so the managed repository link exists before the hook runs. A direct
tool install on a clean, unconverged machine must apply dotfiles first rather
than depend on the physical checkout path as a fallback.

## Checklist

- [x] Confirm the stable helper works in the live Git configuration.
- [x] Add the warning comment and GitHub CLI source link.
- [x] Define and approve the checker executable as the public test seam.
- [x] Add a failing test for stable helper validation.
- [x] Implement the minimum checker behavior for the stable case.
- [x] Add and satisfy pinned-helper rejection coverage.
- [x] Add and satisfy resolver-version mismatch coverage.
- [x] Add the tool-level `gh.postinstall` declaration.
- [x] Run static, formatting, live read-only, and diff validation.
- [x] Record verification results and final file scope in this plan.

## Verification

- `test/gh-credential-helper_test.sh`: passed stable, missing, pinned, and
  resolver-mismatch cases.
- `shellcheck bin/check-gh-credential-helper test/gh-credential-helper_test.sh`:
  passed.
- `bash -n bin/check-gh-credential-helper test/gh-credential-helper_test.sh`:
  passed.
- `mise fmt --check`: passed.
- `bin/check-gh-credential-helper`: passed against the live managed Git
  configuration without requesting credentials.
- `mise ls --current gh`: resolved `gh` 2.101.0 from the configured `2` request.
- `mise tool gh --json`: recognized the checker as the active tool-level
  `postinstall` option.
- `git diff --check`: passed.

The final implementation scope is `mise/config.toml`,
`mise-dots/gitconfig`, `bin/check-gh-credential-helper`,
`test/gh-credential-helper_test.sh`, and this plan. The pre-existing unrelated
worktree files remain untouched.
