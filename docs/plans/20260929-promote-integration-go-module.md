# Promote the integration Go module to the repository root

Status: Implemented on PR #9. Local and macOS and Linux CI checks passed on
2026-09-29.

Move the integration suite's `go.mod` to the repository root while keeping
`mise run test:integration`, CI, and the installed gitleaks hook test working.
Keep `toolchain go1.27.1` as the single project Go version declaration.

## Proposed shape

- Move `test/integration/go.mod` to `go.mod`. Set its module path to
  `github.com/oppegard/dotfiles`; keep the `go` and `toolchain` lines.
- Move `idiomatic_version_file_enable_tools = ["go"]` into root `mise.toml`
  and delete `test/integration/mise.toml`. Make the root task run
  `go test ... ./test/integration` directly. Root `mise.toml` and root
  `go.mod` then describe the same project toolchain.
- Run `jdx/mise-action` from the repository root and update its cache key to
  hash root `go.mod`. The action will install and cache the project Go version.
- Keep the isolated hook fixture's bare `mise install`. It must install the
  complete root tool set, including Go, before the clean, secret, and bypass
  commits prove that the installed hook runs gitleaks.
- Update the README path and any other references to the old `go.mod` path.
  Leave the CI change classifier and suite layout alone.

A scratch project with root `go.mod`, root mise Go detection, and a root task
selected Go 1.22.12 from the root module. This confirms version resolution
without changing the checkout. Root Go detection will make ordinary root
`mise install` and CI's lint setup install Go too. That cost is acceptable for
a coherent root toolchain. The owner explicitly wants bare `mise install` to
install every root tool, including in the lint job and hook fixture. The root
setting also replaces the home configuration's node and ruby version-file
list inside this checkout; the repository has no node or ruby version files.

## Refactoring playbook

1. Pin the behavior contract first. Run the **how** skill over the affected subsystem to learn the contract, then write a characterization test, snapshot, or equivalence harness that captures current behavior before any structure moves. If the area has no coverage, write the pin before touching structure. Type check and lint are not a pin.
2. Name the structure the code is missing per **principle-model-the-domain**. Boring code stays when the shape is already clear and local. The reshape must delete branches or invalid states, not add indirection.
3. Name the target shape. State what the module layout, types, and call graph should be if built today (**principle-foundational-thinking**, **principle-redesign-from-first-principles**). If the target crosses a function boundary, run the **architect** skill for parallel design exploration of the shape before the move.
4. Subtract before you add. Delete dead weight, collapse one-caller wrappers, drop redundant validators, and remove orphan references before introducing the new shape (**principle-subtract-before-you-add**). The smallest change that reaches the target shape ships (**principle-laziness-protocol**). A speculative cleanup that "might help" gets reverted, not left to ride.
5. Move in small behavior-preserving steps, each keeping the pin green. For API reshapes, migrate every caller and delete the old API in the same wave (**principle-migrate-callers-then-delete-legacy-apis**). No compatibility shims, no parallel old-and-new paths. Spot-check every rename against the actual files; renames silently miss usages in strings, prose, and back-references. Delegate mechanical edits to `pstack_builder_luna` with a specific scope (file paths, names being moved, behavior to hold); review the diff yourself.
6. Prove behavior is unchanged on the real artifact, not "it compiles" (**principle-prove-it-works**). For larger reshapes, run an equivalence check: a script that diffs old-vs-new outputs, a recorded baseline replayed against the new code, or a smoke run on the matching surface via the relevant control skill. Own the verification yourself; do not trust a delegate's "looks good" summary.
7. Confirm the change earns its place. The success measure is reduced reader load (**principle-minimize-reader-load**): fewer layers between question and answer, less hidden state, fewer indirections without a second consumer. If the diff does not lower reader load somewhere, revert it.
8. Rebase into small ordered commits that tell the story. A subtraction commit, then the reshape, then any follow-on cleanup, so a single revert undoes one slice. Shape them with the **sequence-verifiable-units** principle skill, so each behavior-preserving slice stays green before the next. Run **Opening a PR**.

For this move, the current Go suite is the behavior pin. No Go imports cross
package boundaries. One commit can hold the move and its references. No new
abstraction is needed.

## Implementation checklist

- [x] Record current Go selection: the nested module used Go 1.27.1.
- [x] Move `go.mod`, change the module path, move the mise setting to the
  root, and delete the nested mise config. Simplify the root task.
- [x] Move the CI setup to the root, update its cache key, and update the
  README reference.
- [x] Keep the isolated hook fixture's bare `mise install` and verify that it
  installs Go as well as hk and gitleaks.
- [x] Verify root mise selects Go 1.27.1 from root `go.mod` without using
  the home Go version.
- [x] Run `mise run test:integration`; confirm the isolated hook rejects the
  synthetic secret and the bootstrap guard stays in effect locally.
- [x] Run `actionlint` and `mise run lint`.
- [x] Run staged and unstaged `git diff --check` after the final stage.
- [x] Review the exact staged diff.
- [x] Make one Conventional Commit on the current PR branch for review.
- [x] Update PR #9's collapsed Implementation Plan and inspect macOS and
  Linux CI. Do not merge the PR.

## Verification

- `mise exec -- go version` returned Go 1.27.1 from root `go.mod`.
- The local integration suite passed. The bootstrap test skipped before
  machine changes. The isolated hook fixture's bare `mise install` installed
  seven tools, including Go, hk, and gitleaks. The hook accepted clean
  content, rejected the synthetic secret, preserved `HEAD`, and allowed the
  same staged secret only with `--no-verify`.
- `actionlint` and `mise run lint` passed.
- Staged and unstaged `git diff --check` passed. The staged diff contains
  the module move, root mise setting and task, CI cache path, README, and
  this plan.
- The commit's installed pre-commit hook passed gitleaks, yamlfmt, tombi,
  and newlines checks.
- [Integration run 36605794524](https://github.com/oppegard/dotfiles/actions/runs/36605794524)
  passed on macOS and Linux. Each job installed seven tools from root
  `mise.toml`, including Go 1.27.1; passed both bootstrap runs; and proved
  that the installed hook rejects the synthetic secret while preserving
  `HEAD`. The same staged secret committed with `--no-verify`.
- [Lint run 36605794566](https://github.com/oppegard/dotfiles/actions/runs/36605794566)
  passed. Its root mise setup installed all seven tools, including Go 1.27.1.

## References

- Mise Go version files: https://mise.jdx.dev/lang/go.html#go-version-files
- Mise directory selection: https://mise.jdx.dev/dev-tools/
- Go toolchain selection: https://go.dev/doc/toolchain
