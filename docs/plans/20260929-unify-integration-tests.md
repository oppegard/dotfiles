# Unify integration tests under Go

Status: Approved and in progress on 2026-09-29.

The `Integration Tests` workflow will run one Go test package on macOS and
Linux. `mise run test:integration` will invoke that same package locally. The
package will cover the two `bin/dotf run` passes and the installed gitleaks
pre-commit hook. The workflow from PR #8 will then be removed.

## Figure it out playbook

- [x] Read the Principles section of the poteto-mode skill.
- [x] Phase A: Frame. State a falsifiable definition of done, scope, and risks.
- [x] Phase B: Design the workflow. Put isolation and verification before the
  port, and split the work into units with a check after each.
- [ ] Phase C: Run the loop. Implement and verify one unit at a time after this
  plan is approved. Final CI verification remains open.
- [x] Phase D: Keep the audit trail. Record commands, results, and relevant CI
  run links in this plan as each unit lands.
- [ ] Phase E: Verify and hand back. Check the final workflow and local command
  against the definition of done.

## Definition of done

The migration is complete when all of these observations hold at the final
commit:

- `mise run test:integration` runs the Go suite on a local macOS or Linux
  machine with Go 1.27 and mise available. The full bootstrap test requires a
  disposable machine or VM. Its preflight must stop before any bootstrap action
  when that condition is not met and report the bootstrap test as skipped. The
  command must display that skip clearly. The hook test uses its own temporary
  home and repository and can run on a normal development machine.
- The Go suite invokes the first and second `bin/dotf run` passes and checks
  their exit status and resulting state. It preserves the workflow's `CI`,
  `NONINTERACTIVE`, `MISE_ENV=home`, and macOS package-manager settings where
  those settings affect the bootstrap.
- A clean commit succeeds through the installed hook. A staged synthetic AWS
  key makes `git commit` fail with gitleaks detection evidence, leaves `HEAD`
  unchanged, and leaves the file staged. This runs on both macOS and Linux.
- A deliberate hook bypass in a disposable fixture makes the gitleaks test
  fail. The normal test must fail when `mise install` does not install a hook.
- The single `Integration Tests` workflow has a macOS and Linux matrix, runs
  the same Go suite as the local task with no skipped tests, and passes on the
  final commit. The `pre-commit-e2e.yml` workflow is gone. The required matrix
  check names remain
  stable or the repository's branch protection is updated by its owner.

## Current state and risks

`integration-tests.yml` runs `bin/dotf run` twice in a shell step on
`macos-latest` and `ubuntu-26.04`. It clears three files in the runner's home
and mocks `chsh` on macOS. The separate workflow runs a Go 1.27 hook test only
on Ubuntu. `test/hooks/pre_commit_test.go` explicitly skips every non-Linux
host. PR #8 added that test and workflow and has merged.

The bootstrap invokes `mise bootstrap` against the checked-out user config.
That config declares packages, services, dotfiles, and macOS settings, so an
ordinary developer host is not a safe target. A temporary `HOME` alone cannot
contain Homebrew packages, login-shell changes, services, or system files. The
full local bootstrap lane therefore needs a disposable machine or VM. The Go
preflight must check an explicit disposable-environment marker and explain the
requirement before it runs `bin/dotf run`. CI runners satisfy this contract.
The hook lane stays safe to run on the host through its existing isolated
repository and mise directories.

The existing change-detection job does not expose `integration_optional` as a
job output, yet the matrix job reads it. Its prose-or-test-only skip also risks
skipping changes to the integration suite itself. Remove this optimization as
part of consolidation so every pull request runs both platform checks. Keep
the schedule and manual trigger.

The current machine has Go 1.26.8, while the existing module requires 1.27.
The local command needs Go 1.27 in `PATH`. Set up Go 1.27 in CI; do not add a
new production tool declaration to the root `mise.toml` without approval.

## Proposed test shape

Move the existing hook test into one `test/integration` Go module and package.
Keep separate named tests for bootstrap idempotence and hook rejection, so a
failure names its behavior while one `go test` command runs the suite. The
shared data shape is a test case's temporary checkout, home, environment, and
captured command result. Keep the bootstrap and hook fixtures separate because
they have different isolation requirements. Avoid a generic command framework.

The Go bootstrap test will create a disposable checkout and home, set the
runner environment, run `bin/dotf run` twice, and assert both the expected
first-run state and a clean second run. Preserve the macOS `chsh` stand-in in
the disposable home and the `MISE_SYSTEM_PACKAGES_MANAGERS=brew` restriction.
Record what a successful bootstrap must leave behind before porting the shell
commands. Do not use a stubbed `mise bootstrap` as the sole proof of the real
bootstrap path.

Adapt the PR #8 hook test to macOS while retaining its fresh mise install and
real Git commits. Replace the Linux-only skip. Check platform-specific path and
tool assumptions, especially the narrow `PATH`, `/dev/null`, and executable
lookup. Reuse its synthetic key and gitleaks-specific assertions. Keep the
test independent of the bootstrap test so failure order does not mask a broken
hook. The suite must not install a hook manually to repair a failed postinstall.

Add `[tasks."test:integration"]` to root `mise.toml` with a command that enters
the Go module and runs `go test -v -count=1` with a bounded timeout. Use the
same command in the workflow. Document the local prerequisite and disposable
bootstrap requirement next to the task or in the repository test instructions.
Do not add third-party Go modules.

Use `jdx/mise-action` with `install: true` and `cache: true` in CI. Its cache
key includes the runner platform, the root mise configuration, and the user
bootstrap configuration. Share its mise data and cache directories with the
bootstrap test. Keep the hook test's mise directories fresh, so a cache hit
cannot hide a missing hk postinstall hook. `actions/setup-go` keeps its module
cache disabled because this standard-library-only module has no `go.sum`.

## Implementation checklist

### 1. Capture the baseline and safety contract

- [x] Record the current two-pass workflow behavior on a disposable macOS and
  Linux runner, including exit status, key output, installed files, and repeat
  behavior. Record whether the current workflow's skip path ever executes.
- [x] Identify the smallest reliable CI marker and local VM marker for the Go
  bootstrap preflight. Prove that a normal host is skipped before a bootstrap
  subprocess starts.
- [x] Record existing hook-test output and rerun the PR #8 bypass experiment in
  an isolated fixture. Treat missing gitleaks evidence as failure.

### 2. Port bootstrap behavior into Go

- [x] Add the bootstrap test and its isolated checkout and home fixture.
- [x] Move each current workflow condition into the Go runner or a documented
  CI setting. Assert first-run and second-run results, not just zero exits.
- [ ] Run the test on disposable Linux and macOS environments. Compare results
  with the baseline before deleting the shell step.

### 3. Unify the hook test and local command

- [x] Move the hook test into `test/integration` and make it run on both hosts.
- [ ] Run the real clean and secret commits on macOS and Linux. Verify the
  deliberate hook-bypass case fails the test on both hosts.
- [x] Add `mise run test:integration`. Check its discovered task and command on
  both hosts. On a normal host, prove that it runs the hook lane and reports a
  bootstrap skip before any machine change.

### 4. Consolidate CI

- [x] Change `integration-tests.yml` to install Go 1.27 and mise, then invoke
  `mise run test:integration` once in each existing matrix leg. Retain runner
  timeouts and make the full suite's timeout cover fresh installs.
- [ ] Remove the change-detection skip and delete `pre-commit-e2e.yml` after
  both Go tests pass in the consolidated workflow.
- [ ] Run `gofmt`, `go test`, `actionlint`, `mise run lint`, and
  `git diff --check`. Inspect the final macOS and Linux job logs for both
  bootstrap passes and gitleaks rejection. Confirm the jobs ran on the final
  commit, rather than accepting a skipped or stale check.
- [ ] Update this checklist and the PR's collapsed `Implementation Plan` as
  work proceeds. Do not merge the PR.

## Open decision for review

The full bootstrap mutates machine state by design. This plan treats a local
disposable VM as the requirement for running it, while the hook test runs on a
normal host. If `mise run test:integration` must run the full bootstrap safely
on an ordinary host, the implementation needs a separate containment design
that blocks package, service, shell, and system-file writes. That design is not
established by the current workflow or PR #8.

## Evidence log

| Unit | Evidence | Result |
| --- | --- | --- |
| Plan investigation | Current workflow, `bin/dotf`, mise config, and merged PR #8 | Complete |
| Baseline and safety contract | [Prior CI run](https://github.com/oppegard/dotfiles/actions/runs/36578026572) completed both bootstrap passes on macOS and Linux. Local preflight skipped bootstrap before any subprocess. | Verified |
| Go bootstrap and hook suite | Hook passed on macOS. A temporary `git commit --no-verify` mutation caused the expected test failure. Bootstrap awaits disposable CI. | Partial |
| Local command | `mise run test:integration` passed the hook test and reported the bootstrap skip on macOS. | Verified for normal host |
| Final macOS and Linux CI | Pending | Not verified |

## Sources

- [Merged PR #8](https://github.com/oppegard/dotfiles/pull/8)
- [mise task documentation](https://mise.jdx.dev/tasks/)
- Repository workflows, `bin/dotf`, `bin/bootstrap`, root `mise.toml`, user
  mise config, and `test/hooks/pre_commit_test.go` at `main` on 2026-09-29.
