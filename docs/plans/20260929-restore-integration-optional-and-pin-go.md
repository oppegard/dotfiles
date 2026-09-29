# Restore optional integration checks and pin Go in the module

Status: Implemented on PR #9. Full macOS and Linux CI passed on 2026-09-29.
The no-op GitHub job path can be observed after this workflow reaches `main`.

PR #9 already runs one Go integration suite on macOS and Linux. Restore the
prose-only shortcut without losing either required matrix check. Make the
integration module's `go.mod` the one file that chooses the exact Go toolchain
for local runs and CI.

## Feature playbook

- [x] 1. `how` over the affected subsystem.
- [x] 2. `architect` for parallel design exploration. Skipping stays as
  `architect skipped: <reason>`. Architect skipped: the change is a workflow
  classifier and one task command; a local mise prototype settled the tool
  resolution question.
- [x] 3. Write the throughput checkpoint as four todo items. A dimension that
  genuinely does not apply (single file, no fan-out) keeps its item with
  `n/a: <reason>` rather than being dropped.
  - Blocking first steps: approve this plan before source edits. Approved on
    2026-09-29.
  - Independent workstreams: n/a. Workflow and task changes share the Go
    version decision.
  - Shared mutable state: the owner removed the uncommitted `#go = "1.27"`
    line before implementation began.
  - Smallest safe decomposition: make the Go version path work, then add the
    change classifier, checking each unit.
- [x] 4. Delegate code-writing using model routing. If nested spawning is
  unavailable, the current agent owns the diff directly. Review every diff.
- [x] 5. Verify on the matching surface. The full CI path and local Go task
  passed. The no-op GitHub path awaits a docs-only PR after merge.
- [x] 6. Rebase into small, ordered commits; stack follow-ups. One scoped
  implementation commit was pushed to the existing PR.
- [x] 7. If the design is contested, `interrogate` before shipping.
  Skip: no design disagreement remains after the mise prototypes and review.
- [x] 8. Run Opening a PR. PR #9 already exists, so update its description and
  checks rather than opening another PR.

## Current behavior and decision

The current root task starts from the repository root, then uses `cd` inside
its shell command. On this Mac, mise puts the home-configured Go 1.26.8 on
`PATH`. The Go command then switches itself to cached Go 1.27.0 after entering
the module. This runs the module, but neither mise nor CI selects one exact
project version.

Mise's Go version-file support is opt-in. Its current documentation says that
reading the `go` directive as a version request is deprecated and scheduled
for removal in mise 2026.11.0. Mise reads an exact `toolchain goX.Y.Z` line
instead. Go treats `go 1.27` as the module's minimum version and the
`toolchain` line as its preferred development toolchain. The `setup-go`
action also reads `toolchain` before `go` when given this module's `go.mod`.

Use `go 1.27` and `toolchain go1.27.1` in `test/integration/go.mod`. Go 1.27.1
is the current Go 1.27 patch release on 2026-09-29. Do not declare another
Go version in root `mise.toml` or the home configuration. Enable mise's Go
version-file discovery in `test/integration/mise.toml`, which the local task
and CI setup both load.
The owner removed the experimental `#go = "1.27"` line before implementation.

A scratch prototype showed that `dir = "module"` changes a task's working
directory but does not select that module's tools when the task was launched
from the parent. A nested `mise -C module exec -- ...` does select the
module's version. The root task will use that command and keep the same
`mise run test:integration` entry point.

Moving `go.mod` to the repository root would let mise select Go directly
after enabling Go version-file discovery in root `mise.toml`. The prototype
confirmed this. It would also make the hook test's isolated repository run
install Go during its `mise install`, because that test copies all tracked
files and installs the project tools in a fresh mise data directory. The
hook test needs hk and gitleaks, and a Go install there would add a second
download on every platform. Keep the module beside the integration tests and
use mise's documented directory selection for this one task and CI setup.

For CI, set `working_directory: test/integration` on `jdx/mise-action` and
load the module-local mise configuration. Its install reads the nested
`go.mod` and caches Go together with the existing mise tools. Include both
module configuration files in its cache key. Remove `actions/setup-go` so CI
does not install Go twice. The action saves its cache during setup, so
installing Go later in the test step would miss that cache.

## Optional check behavior

On pull requests to `main`, classify the complete branch diff from the merge
base with `main` to the PR head. Return `integration_optional=true` only when
the diff is nonempty and every changed path is exactly `AGENTS.md`, exactly
`README.md`, or under `docs/`. A change to `test/`, `mise.toml`, a workflow,
or any other path runs the full suite. Scheduled and manual runs always run
the full suite. A classification failure fails both required checks.

Restore a `detect-changes` job with an explicit job-output mapping for
`integration_optional`. Keep both matrix entries and their current check
names. When optional, each matrix job runs a single echo step and no setup,
checkout, or Go test steps. Use the former workflow's `ubuntu-slim` runner
for both no-op entries to avoid macOS runner cost while retaining the matrix
check names. When required, each entry runs on its named macOS or Linux
runner and executes the full Go suite.

## Implementation checklist

- [x] Add the module's exact `toolchain` line. Verify that mise selects
  Go 1.27.1 from the nested module while root Go remains independent.
- [x] Update the root task so `mise run test:integration` selects the nested
  module's Go. Verify `go version` on the actual task path and run the hook
  test on a normal Mac. Preserve the bootstrap preflight and confirm that the
  isolated hook fixture does not install Go.
- [x] Configure `mise-action` to install from the module directory and cache
  that Go version. Remove the separate `setup-go` step.
- [x] Restore `detect-changes`, its job output, and the no-op matrix path.
  Exercise docs-only, mixed, renamed, empty, schedule, and detector-failure
  cases against the classifier.
- [ ] Run `actionlint`, `mise run lint`, the local integration task, and
  `git diff --check`. Inspect both full CI matrix jobs for Go 1.27.1,
  bootstrap passes, and gitleaks rejection. Inspect a docs-only PR run to
  confirm both matrix check names succeed through the no-op path.
- [x] Update PR #9's collapsed Implementation Plan and record final evidence
  here. Do not merge the PR.

## Evidence log

| Check | Result |
| --- | --- |
| Mise version resolution | With `test/integration/mise.toml`, `mise -C test/integration exec -- go version` returned `go1.27.1 darwin/arm64` from mise's Go 1.27.1 install. Root mise still resolves the home Go 1.26.8. No environment override is needed. |
| Local suite | `GOCACHE=/private/tmp/dotfiles-go-build mise run test:integration` passed with network access. Bootstrap skipped before machine changes on this normal Mac. The isolated fixture installed six tools, including hk and gitleaks, and did not install Go. The installed hook rejected the synthetic secret and preserved `HEAD`; the same staged secret committed with the hook bypassed. |
| Change classification | The workflow's actual Bash block passed scratch Git cases for empty, allowed-only, schedule, mixed, advanced-base, and docs-to-test rename diffs. The implementation owner also exercised manual, invalid-base, and docs-to-docs cases. |
| Static checks | `actionlint` passed with the existing `ubuntu-26.04` label-table exception. `mise run lint` and `git diff --check` passed. |
| Full CI | [Run 36599860370](https://github.com/oppegard/dotfiles/actions/runs/36599860370) passed the detector and both matrix jobs at `255320b`. Both jobs installed Go 1.27.1 through mise, completed the two bootstrap passes, installed six tools in the hook fixture, rejected the synthetic secret, and committed it with the hook bypassed. The paired lint run passed. |
| Mise cache | [Attempt 2 of run 36599860370](https://github.com/oppegard/dotfiles/actions/runs/36599860370/attempts/2) passed both matrix jobs. Each job restored its platform cache, reported Go 1.27.1 already installed, and still ran the hook fixture's fresh six-tool install. |
| No-op GitHub path | The classifier's exact Bash block passed scratch Git cases. A docs-only PR cannot trigger this new workflow against `main` before PR #9 merges, because `main` still has the old workflow. Observe the required check names and echo-only steps on the first docs-only PR after merge. |
| Module-local setting | A scratch module proved that a nested `[settings] idiomatic_version_file_enable_tools = ["go"]` selects the nested module's `toolchain` without changing root Go. The updated local integration task passed, including the isolated gitleaks hook test. |

## References

- Mise Go version files: https://mise.jdx.dev/lang/go.html#go-version-files
- Mise minimum-version deprecation: https://mise.jdx.dev/configuration.html#which-fields-mise-reads
- Go toolchain selection: https://go.dev/doc/toolchain
- `setup-go` version-file behavior: https://github.com/actions/setup-go/blob/main/docs/advanced-usage.md#using-the-go-version-file-input
- `mise-action` CI setup: https://mise.jdx.dev/continuous-integration.html
