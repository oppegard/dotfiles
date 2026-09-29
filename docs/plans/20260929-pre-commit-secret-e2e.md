# Verify secret rejection through the installed pre-commit hook

Status: Implemented and verified on Linux in draft PR #8.
Date: 2026-09-29.

## Feature playbook

1. `how` over the affected subsystem.
2. `architect` for parallel design exploration. Skipping stays as `architect skipped: <reason>`. Do not fold the design decision silently into implementation.
3. Write the throughput checkpoint as four todo items. A dimension that genuinely does not apply (single file, no fan-out) keeps its item with `n/a: <reason>` rather than being dropped:
   - **Blocking first steps.** Gates run before fan-out.
   - **Independent workstreams.** Disjoint files, services, or layers parallelize. Shared writes serialize.
   - **Shared mutable state.** Default to splitting the target (the **separate-before-serializing-shared-state** principle skill). Serialize only for real invariants.
   - **Smallest safe decomposition.** If one worker is best, name why.
4. Delegate code-writing using [model routing](../references/model-routing.md), matching the implementation profile to the task difficulty. Give it a specific scope: file paths, the named data shape and its organizing structure per **principle-model-the-domain**, and success criteria. Review its diff yourself. When implementation admits multiple valid shapes, use the **arena** skill so candidates surface alternatives and the cross-judge guards the pick. If nested spawning is unavailable, the current agent owns the diff directly; never return a standing-by response. Comments per **Comments**. Re-ground against source for upstream-derived files, port shared-primitive improvements to all consumers, and verify each.
5. Verify on the matching surface. "Inconclusive" or wrong-surface is not a pass; flag it.
6. Rebase into small, ordered commits; stack follow-ups.
   Use the **sequence-verifiable-units** principle skill, building, verifying, and committing each small unit before the next.
7. If the design is contested, `interrogate` before shipping.
8. Run **Opening a PR**.


## Outcome and scope

Add a Linux GitHub Actions workflow that runs a Go 1.27 end-to-end test.
The test must install the project's tools with `mise install`, let the
configured hk postinstall install Git hooks, and attempt a real commit.
A commit containing a synthetic secret must fail because gitleaks rejects it.
The source checkout, its hooks, and the user's configuration must remain untouched
by test execution.

The root `mise.toml` pins hk 2.0.1 with `postinstall = "hk install --mise"`
and gitleaks 8.30.1. `hk.pkl` enables the gitleaks builtin. `.gitleaks.toml`
extends the default rules. These are the production configurations under test.
The separate dotfile bootstrap configuration is outside this test's scope.

## Proposed design

Use only Go's standard library. Keep the test in `test/hooks/` with a small
`go.mod` requiring Go 1.27 and a single test file. No third-party Go modules.
Install the test runner through the workflow so the root tool configuration
need not change merely to run this test.

The data shape is one isolated test repository, its process environment, and
command results containing output plus an exit error. Keep that state local to
one sequential test. Add only the command helper needed for useful failures.

Use `t.TempDir()` and actual disk files because Git, mise, hk, and gitleaks
are external programs. An in-memory `fstest.MapFS` cannot exercise their behavior.
Compare a full tracked-file snapshot with a minimal configuration copy during
design review. Prefer a tracked snapshot with fresh Git metadata so the test
uses the checked-out PR contents without inheriting local Git configuration.
Do not copy `.git`, credentials, untracked files, or the original remote.

Give subprocesses an isolated home and mise/XDG state. Exclude inherited hook
bypasses, Git configuration overrides, signing requirements, and installed-tool
paths that could hide missing setup. Preserve only necessary execution and
network settings. Initialize local Git identity inside the temporary repository.

Run `mise trust` for the temporary repository and `mise install` from its root.
Use a fresh mise data directory so existing tool installations cannot mask
postinstall behavior. Do not explicitly run `hk install` as a test repair.
Verify installation through actual commit behavior. hk can use an executable
pre-commit hook file or native Git hook configuration on newer Git versions.
The final test accepts both without coupling assertions to their storage format.

Establish a baseline, then commit a clean text fixture through the installed
hook and require success. Generate a deterministic fake token at runtime,
using a confirmed gitleaks default rule, and stage it in that same text file.
Require an ordinary nonzero commit exit, gitleaks-specific detection evidence,
and unchanged HEAD. Process launch errors, timeouts, and unrelated hook failures
must fail the test. Do not embed a complete detectable token in tracked source.

During verification, disable the hook only in a disposable copy and confirm
that the secret commit succeeds and the test rejects that outcome. This proves
that a missing hook cannot produce a passing test.

## Workflow and delivery

Add `.github/workflows/pre-commit-e2e.yml` on `ubuntu-24.04`, triggered by pull
requests to main and manual dispatch. Do not skip draft PRs. Use read-only
contents permission, pinned action revisions, and a bounded job timeout.
Set up Go 1.27.x and the mise executable without installing project tools in
the Actions checkout. Run the test uncached with a bounded Go test timeout.
Keep the cold tool installation inside the Go test.

Run actionlint, gofmt, the relevant existing lint checks, and the actual Linux
workflow. Open a draft PR with the approved plan and current checklist in an
Implementation Plan details section. Inspect the new job's logs and result on
the draft PR's latest commit. Do not merge the PR.

## Throughput checkpoint

- [x] Blocking first steps. Approve this plan, finish design exploration, and
  verify Linux setup and fixture detection before implementing the final test.
- [x] Independent workstreams. Design alternatives can be explored read-only.
  Keep the test and workflow implementation with one owner because they share
  the runner contract.
- [x] Shared mutable state. Test commands write only to a fresh temporary
  directory. One implementation owner edits the feature branch.
- [x] Smallest safe decomposition. One worker owns the Go test and workflow.
  A separate reviewer checks false positives, isolation, and CI results.

## Task checklist

- [x] Read repository instructions and current hook configuration.
- [x] Verify that Go 1.27 is available. The official download endpoint lists
  go1.27.1 on 2026-09-29.
- [x] Obtain approval for implementation.
- [x] Complete parallel design exploration and record the chosen copy strategy.
- [x] Implement the standard-library test and Linux workflow.
- [x] Verify clean commit, rejected secret, and bypassed-hook failure behavior.
- [x] Review the diff independently and run relevant lint checks.
- [x] Commit and push with a Conventional Commits message.
- [x] Create and attach a draft PR with the approved plan.
- [x] Confirm the new workflow passes on the draft PR.

## Design exploration phases

- [x] Ground. Trace mise installation and hk hook dispatch.
- [x] Sketch. Compare two independent designs.
- [x] Agree. The user approved implementation of this plan.
- [x] Implement. Delegate the selected design to one owner.
- [x] Scrap. Not needed. Review found no design contradiction.

Arena phases are Frame, Fan out, Cross-judge, Pick, Graft, and Verify.
The design rubric is authentic setup, isolation, meaningful failure assertions,
and small maintenance cost. Each criterion is scored from 1 to 5.
Two candidates write separate temporary design notes before a read-only judge
compares them. Repository writes remain with one implementation owner.

Design A is the base. Copy tracked working-tree files using `git ls-files -z`
so local edits are tested before committing. Design B used `git archive HEAD`,
which would test stale contents during local development. Both designs rejected
a manually maintained three-file fixture. The independent judge agreed with A.
Scores for authenticity, isolation, rejection evidence, and maintenance were
5/4/4/4 for A and 4/5/4/2 for B. Adopt B's narrow PATH, upstream AWS fixture
assembled at runtime, and native Git hook keys. Keep the bypass experiment as
one-time verification rather than permanent test machinery. All design phases
through Verify are complete.

## Verification progress

Go 1.27.1 compilation and Linux cross-compilation passed. Gofmt, actionlint,
and all repository lint checks passed. Independent review found no correctness
issue after correcting the module owner. The Linux test passed in 5.13 seconds
with Go 1.27.1. Logs confirm fresh installation of six tools and hk's
postinstall creating a native Git pre-commit hook. The clean commit succeeded,
and the secret commit was rejected with the expected detection evidence.

A temporary workflow step added `--no-verify` only to the secret commit.
The test failed with `secret commit succeeded`, proving that hook bypass
cannot yield a passing test. The temporary step has been removed. Final-head
workflow verification is recorded in the PR description before delivery.

- Draft PR: https://github.com/oppegard/dotfiles/pull/8
- Normal and mutation run: https://github.com/oppegard/dotfiles/actions/runs/36577768681

## Sources consulted

- Repository `mise.toml`, `hk.pkl`, `.gitleaks.toml`, and existing workflows.
- https://mise.jdx.dev/configuration.html
- https://go.dev/dl/?mode=json

## Principles used

Test Behavior, Not Implementation requires real `git commit` calls, both clean
and secret-bearing inputs, and observable commit results.
Model the Domain keeps one repository and environment together in the test
instead of adding a generic test framework.
