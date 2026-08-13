# Audit and manage live macOS defaults

## Summary

Use only the live difference between Glenn's macOS 15.7.3 (24G419) account and a pristine, no-iCloud temporary account on the same Mac. Do not parse, seed, validate, or migrate any `defaults` commands from `README.md` or git history.

## Implementation

- Add `bin/macos-defaults-audit`, implemented with `/usr/bin/ruby` and Ruby's standard library only, plus macOS's built-in `defaults` and `plutil`.
  - `snapshot --output <file>`: capture effective `NSGlobalDomain`, all `com.apple.*` user-default domains, and Apple/GlobalPreferences host-scoped (`ByHost`) plists. Export each plist as XML, parse it with Ruby `REXML`, and record domain, key, plist type, value, host scope, OS build, and hardware metadata.
  - `compare --baseline <file> --current <file> --output <dir>`: emit deterministic JSON and Markdown reports containing only domain/key pairs that differ, including absent domains/keys and type differences.
  - Classify differences as native mise candidates (bool/integer/float/string, non-host), unsupported host-scoped values, or unsupported complex plist values. Reports and snapshots remain in a mode-700 temporary directory and are never committed automatically.

- Establish the baseline:
  1. Create a temporary local standard user, with no Apple Account or personalized setup.
  2. Log in once, run the snapshot helper copied temporarily to `/Users/Shared`, and save its baseline snapshot there.
  3. Return to Glenn's account, take the current snapshot, compare it to the baseline, review the report, then remove temporary artifacts and delete the temporary account only after the audit is accepted.

- After review, add only explicitly approved live-diff candidates to `mise/config.macos.toml`:
  - Prefer mise's friendly macOS sections when an audited key maps exactly to one.
  - Put all other approved scalar values in `[bootstrap.macos.defaults]`, preserving their audited domain, type, and value.
  - Do not duplicate a friendly-section key in the raw table.
  - Store approved host-scoped and composite values in a separate audited manifest; expose a read-only `mise` task to verify them. Do not add a custom apply mechanism for unsupported values.
  - mise will manage only per-user scalar defaults; it cannot manage `-currentHost`, system (`sudo defaults`), arrays, dictionaries, dates, or data values. [mise macOS Defaults documentation](https://mise.jdx.dev/bootstrap/macos-defaults.html)

- Update `bin/setup.sh`'s Darwin path to run `mise bootstrap macos defaults status` after the existing `mise bootstrap`, so setup reports drift without changing preferences. Applying is always explicit and confirmed with:
  - `mise -C mise bootstrap macos defaults apply --dry-run`
  - `mise -C mise bootstrap macos defaults apply`

- Replace the README's manual defaults recipe with the audited mise workflow and restart guidance. The README is documentation only; it is never an audit input.

## Test plan

- Fixture-test Ruby comparison output for new, changed, removed, type-changed, host-scoped, and composite defaults.
- Run baseline/current snapshots and confirm the report contains no README-derived entries.
- Verify config loading with `mise config ls`; verify generated writes with `mise bootstrap macos defaults apply --dry-run`.
- After explicit apply, require `mise bootstrap macos defaults status --missing` to succeed.
- Run `ruby -c bin/macos-defaults-audit` and `shellcheck` on changed shell scripts.

## Assumptions

- “All macOS defaults” means Apple-owned per-user domains plus global and host-scoped Apple preferences; third-party application preferences and non-`defaults` state are out of scope.
- The desired managed state is the reviewed live state of Glenn's account, not historical README instructions.
- No new dependencies are added; the audit uses `/usr/bin/ruby`, Ruby standard library, and built-in macOS tools.
