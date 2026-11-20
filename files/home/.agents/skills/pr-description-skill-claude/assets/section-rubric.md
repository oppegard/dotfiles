# Section rubric

Apply every check. Fix each failure in the draft, then re-check.

## Whole body

- Visible length (outside `<details>`) fits the PR-shape table in SKILL.md
  step 3.
- Long evidence (full test runs, file lists, logs) sits inside
  `<details>`, so the visible body reads in about one and a half screens.
- No `<placeholder>`, `TBD`, or `TODO` remains.
- Tone is factual. Each adjective names something measurable
  ("one request instead of N"), never praise.
- Every section header from the template is present, unless the repo's PR
  template replaces them. Diagrams is the one section that may be absent.

## TL;DR

- 2-4 sentences: what changed, why now, observable outcome.
- Adds the "why now" that the title does not carry.

## Problem

- At most 6 bullets.
- Each bullet is an observed failure or limit with evidence. A
  hypothetical risk is labelled as one.
- Plain bullets. A `- [x]` or `- [ ]` prefix renders as a checkbox on
  GitHub.

## Approach

- 3-7 bullets or a table, one row per fix.
- Or the single line "Additive change; see Implementation."

## Implementation

- Every file from the diff has an entry, or belongs to a named group
  ("tests for X", "generated files").
- Each entry states intent and scope. The Files changed tab already shows
  the lines.

## Diagrams

- 0-3 blocks; most PRs need one.
- Each block follows a one-sentence legend.
- Nodes and edges name real artifacts from this PR.
- `scripts/validate-mermaid.sh` exits 0 on the draft.

## Trade-offs

- Each bullet names the option chosen, the option rejected, and the
  reason.
- 1-2 bullets for a mechanical PR; 3-5 for a cross-cutting one.
- Any skipped Scenario Evidence table names its skip case here.

## Validation

- Each output block is preceded by its command.
- The visible block may show only the result lines (pass/fail summary,
  failures, warnings). The full, unfiltered transcript goes in
  `<details>`.
- Skipped commands are named, with the reason.
- A behavior change has a Scenario Evidence table that passes
  `assets/scenario-evidence-rubric.md`.

## How to test

- At most 5 task-list steps (`- [ ]`).
- Each step pairs an action with an expected observation.
- Each step runs from a fresh checkout plus the setup the body states.

## Evidence

- Every quoted line appears verbatim at its link.
- Every permalink uses a pushed head SHA, not a branch name.
- Every claim about another repo or tool rests on a primary source checked
  in this run.
- Every issue and PR number exists: check with `gh issue view` or
  `gh pr view`.
