# Git Tab completion regression test

Status: complete. Approved on 2026-10-01. Brewfile CI verified.
PR: https://github.com/oppegard/dotfiles/pull/21

## Workflow

The Feature playbook steps follow verbatim. Its relative model-routing link
refers to the installed [model-routing reference](/Users/glenn/.codex/plugins/cache/pstack-codex/pstack-codex/0.15.0+codex.20260929221339/skills/poteto-mode/references/model-routing.md).

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


## Proposed change

Add a macOS-only Git completion check to the existing Go integration suite.
Run it after bootstrap prepares the managed Bash, Git, and shell files.
Install the formula declarations from `Brewfile` in macOS CI before the
suite. Preserve the existing cask exclusion. Keep the existing Linux bootstrap checks.

The data shape is a terminal transcript. The test sends literal keystrokes
to a fresh interactive Bash login shell and checks the resulting completion
candidates. It does not call private Git or fzf completion functions.

Use macOS `/usr/bin/script` to provide a pseudo-terminal. Keep its input
pipe open, wait for a unique ready marker after shell startup, and then send
`git che` followed by one Tab. Preserve the managed `.inputrc`, which
shows candidates when completion is ambiguous. Assert that the transcript contains
`checkout` and `cherry-pick`. Clear the unfinished command with Ctrl-U and exit Bash.
Give the child process a bounded timeout and include its transcript on
failure. Do not install another dependency or change shell configuration.

A small test helper may own the child process, input pipe, readiness marker,
transcript, and timeout. Its only caller is the bootstrap test. Confirm the
smallest reliable shape with a terminal experiment before committing it.

## Reasoning and alternatives

Calling a completion function would check the function's output but miss
Readline dispatch and startup order. A source-order assertion would pass
without proving that Tab works. The terminal transcript observes the
behavior that failed for the user.

The shell completion setup is currently macOS-specific. A Linux Git
completion assertion would require a separate configuration change.
Missing completion packages on the disposable macOS runner must fail the
test, rather than skip it.

## Throughput checkpoint

- Blocking first steps. Review and approve this plan, then prove the terminal
  interaction before implementation.
- Independent workstreams. One worker owns the coupled Go test changes.
  Independent review begins after the diff exists.
- Shared mutable state. Use a separate branch or worktree and temporary test
  artifacts. Local verification must not run destructive bootstrap.
- Smallest safe decomposition. One test owner avoids competing edits to the
  bootstrap lifecycle and terminal driver.

## Workflow choices

- How completed through source inspection and a read-only explainer.
- Architect skipped: this adds one behavior assertion to the existing
  bootstrap lifecycle. No production interface or architecture changes.
  Revisit if the terminal driver needs a general abstraction.
- Interrogate skipped unless review exposes a contested design.
- Shipping skipped: the user requested a PR, not a merge.

## Task checklist

- [x] Inspect the suite, CI, and shell startup path.
- [x] Identify the pseudo-terminal input lifetime constraint.
- [x] Obtain approval for this plan.
- [x] Prove ready-gated terminal input and clean process shutdown.
- [x] Implement the macOS completion check in the existing suite.
- [x] Run it against the fixed shell configuration.
- [x] Demonstrate that it fails with the pre-fix startup order in an isolated
      fixture. Restore the fixed fixture and demonstrate that it passes.
- [x] Verify timeout cleanup and transcript diagnostics.
- [x] Run targeted Go tests and repository lint.
- [x] Complete independent correctness and comment review.
- [x] Commit and push the branch.
- [x] Open a PR with this plan and its current checklist in a collapsed
      Implementation Plan section.

## Acceptance

The completion check runs in macOS integration CI after real bootstrap.
It detects the original fzf-before-bash-completion regression by sending
Tab bytes through Readline. It neither runs local bootstrap nor changes
production shell configuration. The final deliverable is an open PR.

## Verification record

- The same native terminal probe showed `checkout` and `cherry-pick` after
  one Tab with the fixed startup order and neither with the original order.
- The actual Go helper passed the fixed fixture and returned a completion
  timeout with a transcript for the original order under `go test -race`.
- A blocked startup fixture returned a startup timeout. Its Bash and sleep
  child processes both exited. A child-process start error returned promptly.
- The race detector caught an embedded `bytes.Buffer.ReadFrom` method that
  bypassed the locked writer. Private buffer and mutex fields removed that
  path. The updated runtime probes pass with the race detector.
- `go test -race ./test/integration -run '^TestDotfBootstrapTwice$' -count=1`
  compiled the suite and skipped bootstrap under the existing local guard.
- Linux amd64 test-package compilation, `go vet ./test/integration`, Go
  formatting, `git diff --check`, and `mise run lint` passed.
- Independent correctness review found no issues in the updated diff.
  Comment review found no source comments to remove. Its claimed Start-error
  hang was rejected after checking defer order and running the Start-error
  probe. The required verbatim workflow excerpt is retained.
- Full bootstrap and the new post-bootstrap subtests have not run locally.
  The existing macOS integration CI will exercise that path on a disposable
  runner.

## CI prerequisite repair

The first GitHub macOS run timed out during both completion subtests.
`dotf run` invokes mise bootstrap, but `fzf` and `bash-completion@2` are
Brewfile packages installed by `setup.sh`. The original test assumed those
prerequisites were already installed. The default Bash prompt does not prove
that shell files were missing, because Starship is also a Brewfile package.

The repair installs only those two existing formulas on disposable macOS CI.
Before each terminal check, the test verifies that `.bash_profile`, `.bashrc`,
`.inputrc`, and `.config/shell/inits` resolve to the checkout sources. It keeps
the original one-Tab assertion, timeout, and transcript diagnostics.

- [x] Read the failed job transcript and trace package ownership.
- [x] Add explicit macOS completion prerequisites to CI.
- [x] Verify shell source identity before terminal interaction.
- [x] Validate the repair locally and complete independent review.
- [x] Push the repair to PR #21 and verify macOS integration CI.

The repaired code passed [macOS integration CI](https://github.com/oppegard/dotfiles/actions/runs/36945135894/job/110645434910).
Both `git_completion_after_run_1` and `git_completion_after_run_2` passed,
including startup-file source checks. Linux integration CI and lint passed.
The PR watcher reported `READY` with merge state `CLEAN`. The PR remains open.

## Brewfile follow-up

The user requested replacing the package-specific install with the existing
Brewfile. GitHub macOS runners already provide Homebrew. Use `brew bundle
install --file=Brewfile --no-upgrade` and derive `HOMEBREW_BUNDLE_CASK_SKIP`
from `brew bundle list --cask --file=Brewfile`, preserving the current CI
policy that excludes desktop apps. No package names are duplicated in CI.

Cache the directory returned by `brew --cache` with GitHub's pinned
`actions/cache` action. Scope the key to the runner OS, architecture, image,
and Brewfile hash. Continue running bundle install on cache hits because
the cache stores downloads, not installed packages.

Homebrew's prefix-cache action supports Brewfile, but requires removing
preinstalled formulas on these runners. Download caching avoids replacing
the runner's Homebrew prefix. Architect skipped because this changes only
workflow package preparation and adds no interface. One workflow writer
and a separate reviewer keep the diff bounded.

- [x] Confirm hosted-runner and Homebrew cache support from official sources.
- [x] Record the user-requested Brewfile change in this approved plan.
- [x] Replace explicit package installation and add download caching.
- [x] Run workflow lint and independent review.
- [x] Push to PR #21 and verify the Brewfile install and both Tab checks.

Actionlint, repository lint, and diff checks passed. Independent review
found that the Actions `env` context omits inherited runner variables.
The cache setup now exports the image identity through a step output.
[The cold-cache macOS run](https://github.com/oppegard/dotfiles/actions/runs/36947486516/job/110652803429)
installed all 17 Brewfile formula declarations, skipped the desktop casks,
and passed both Git completion subtests. The download cache was saved with
the expected OS, architecture, image, and Brewfile key. Linux integration
and lint passed. A final documentation push will also exercise cache restore.

## Remove Homebrew download caching

The user requested removing the download cache after comparing run times.
The cold Brewfile install took 27 seconds. Cached installs took 27 and 32
seconds, plus cache restoration. Successful restoration did not demonstrate
a net speed improvement. Delete the two Homebrew cache steps and keep the
Brewfile install. Existing mise caching belongs to the bootstrap tool setup
and is unchanged by this reversal.

- [x] Record the requested reversal and its measured reason.
- [x] Remove Homebrew cache discovery and restore/save steps.
- [x] Run Actionlint, repository lint, and independent review.
- [x] Prepare PR #21 update for GitHub verification.

The PR verification section records the GitHub result for this reversal.
