---
name: pr-description-skill-claude
description: Writes a pull request description as one GitHub-Flavored Markdown file, with evidence-backed reasoning, validated mermaid diagrams, and real test output. Use when asked to write, draft, or update a PR description or PR body, or to open a PR.
---

# PR description

Produce one PR body file a reviewer can judge without opening anything
else. Every claim in it carries **evidence**: a link, a `file:line`, an
issue, a prior PR, or verbatim command output. A claim without evidence is
cut, or restated as a trade-off.

## 1. Gather inputs

Collect every row before drafting. Mark a row `none` only after its
lookup comes back empty.

| Input | Lookup |
|---|---|
| Base ref | `gh pr view --json baseRefName`; else `gh repo view --json defaultBranchRef` |
| Existing PR body | `gh pr view --json body` |
| Repo slug, head SHA, pushed? | `gh repo view --json nameWithOwner`; `git rev-parse HEAD`; `git branch -r --contains HEAD` |
| Changed files | `git diff --name-status <base>...HEAD` |
| Full diff | `git diff <base>...HEAD` |
| Commits | `git log --no-merges <base>..HEAD` |
| Motivation and why now | linked issue in commits, branch name, or plan; else ask the user |
| PR template | `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`, `docs/`, or repo root |
| Plan file | `git diff --name-only <base>...HEAD -- 'doc/plans/*.md' 'docs/plans/*.md'`, or a plan the user names |
| Validation output | the repo's lint and test commands, run now, output kept verbatim |

Find lint and test commands where the repo declares them: AGENTS.md,
`mise tasks ls`, `hk.pkl`, Makefile, `package.json` scripts, CI workflows.
Read each command's definition before running it. Run the ones confined to
the repo; skip one that deploys, needs a disposable machine, or writes
outside the repo, and name it as skipped in Validation. When lint or tests
are red, stop and report the failure; the body describes a green branch.

Done when every row holds a value or `none`.

## 2. Read the diff

Read the full diff. Keep a one-line intent note per changed file in your
working notes: what changed, and what was deliberately left alone. The
notes become the Implementation section. Done when every file in
`--name-status` has a note.

## 3. Draft

Load `assets/pr-body-template.md`. When the repo has a PR template, its
headings win; fit the skill's sections inside them.

Size the body to the diff. Count the lines a reviewer sees: lines inside
`<details>` and the appended plan do not count.

| PR shape | Visible lines |
|---|---|
| Docs-only, dependency bump, one-line fix | 15-40 |
| Feature or fix within one component | 50-150 |
| Change across component boundaries (modules, services, public APIs) | up to 220 |

When the PR changes what a user, caller, or script observes, load
`assets/scenario-evidence-rubric.md` and build the Scenario Evidence table.

When a plan file exists, append it as committed at HEAD in a collapsed
`<details><summary>Implementation Plan</summary>` block at the end. When
its checklist lags the branch, tell the user in the step-6 reply.

Evidence for a claim about another repo, tool, or service is a primary
source: its docs, its code, or a command run now. A plan or commit message
records the author's belief; verify it, or cut the claim.

Permalinks need the head pushed. When `git branch -r --contains HEAD` is
empty, use repo-relative paths and say so in the step-6 reply.

## 4. Diagrams

Add a diagram when the change touches control flow, data flow, state, or
more than one component. Load `assets/mermaid-conventions.md` before
writing the first block. Then validate the draft:

```sh
<directory of this SKILL.md>/scripts/validate-mermaid.sh <draft.md>
```

Done when the script exits 0. Fix each reported block and re-run until it
does.

## 5. Self-check

Load `assets/section-rubric.md`. Apply every check to the draft, fix
each failure, and repeat until all pass.

## 6. Deliver

Write the body to `$(git rev-parse --git-path PR_BODY.md)`; this path
also works in a worktree. Reply with:

- the path,
- a Conventional Commits PR title, at most 50 characters,
- the command that would apply it: `gh pr create --title ... --body-file
  <path>` or `gh pr edit --body-file <path>`.

Run that command only when the user asks for it.
