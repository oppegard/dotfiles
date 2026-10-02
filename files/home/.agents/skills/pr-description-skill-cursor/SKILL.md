---
name: pr-description-skill-cursor
description: >-
  Write one PR body as a markdown file for `gh pr create --body-file`.
  Use when the user asks to write a PR description, draft a PR body, or fill in
  the PR template.
---

# Write a PR body

Write one markdown file. Return the file path and one title line for `gh pr create --title`. Paste the body only when the user asks.

The default path is `.git/PR_BODY.md`.

Put the title only in the `gh pr create --title` argument. Use `<verb>(<scope>): <summary>`, at most 100 characters. The verb is `add`, `fix`, `refactor`, `document`, or `remove`. The scope names the area.

## 1. Read the repository template

Look for `pull_request_template.md` or `PULL_REQUEST_TEMPLATE.md` in `.github/`, then `docs/`, then the repository root.

Also look for a `PULL_REQUEST_TEMPLATE` directory in those three places.

If more than one template file exists, ask which file to fill.

Done when you hold one template's text, or you have checked those paths and none exist.

## 2. Gather facts

Collect every required row before you draft. Stop when a required row is missing. Ask for that row. Do not invent a fact.

| Input | How to get it | Required |
| --- | --- | --- |
| Head branch | `git rev-parse --abbrev-ref HEAD` | yes |
| Base ref | `main`, unless the user names another | yes |
| Files changed | `git diff --name-status <base>...HEAD` | yes |
| Diff | `git diff <base>...HEAD` | yes |
| Commits | `git log --no-merges <base>..HEAD --oneline` | yes |
| Linked issue | the user, or a reference in the commits | when one is named |
| Validation output | run the repository's test or lint task | for a behavior change |

Find the test or lint task in the repository. Check `mise tasks`, `package.json` scripts, a `Makefile`, or a `justfile`. Run that task. Paste its real output.

If the task fails, stop. Report the failure.

Done when every required row is filled, or you have stopped for a missing row or a failed task.

## 3. Choose the shape

Use the repository template when step 1 found one.

Use the short form when the diff is only docs, only a lockfile, or a refactor that keeps the same behavior, the same control flow, and the same component boundaries.

Use the long form for any other diff.

Done when you have named one shape. The shape is `template`, `short`, or `long`.

## 4. Draft

Use only facts from step 2.

On a `github.com` remote, the body is UTF-8 GitHub-flavored markdown. Alerts, `<details>`, and permalinks are allowed. A permalink has the form `https://github.com/<owner>/<repo>/blob/<sha>/<path>#L12-L34`. Get `<owner>/<repo>` from `gh repo view --json nameWithOwner -q .nameWithOwner`. Get `<sha>` from `git rev-parse HEAD`.

On any other remote, write plain markdown and name the file.

**Template.** Fill the file from step 1. Fill every heading. Use only the template's headings.

**Short form.** Write only these sections, in this order.

```markdown
## TL;DR

<2 to 4 sentences. What changed, and why now.>

## Implementation

- **`<path>`** <One sentence of intent.>

## How to test

- [ ] <Action.> <Expected result.>
```

**Long form.** Load [assets/pr-body-template.md](assets/pr-body-template.md). Fill it from the facts in step 2.

Done when the draft file exists at the output path.

## 5. Check mermaid

Skip this step when the draft has no mermaid block.

Quote a flowchart edge label that contains a bracket, a parenthesis, or a pipe. Write `A -->|"[EXEC] work"| B`. The script rejects the unquoted form.

From this skill's directory, run `bash scripts/check-mermaid.sh <draft>`.

Exit 0 means every block rendered. Fix a failing block and run the script again. Continue to step 6 only after exit 0.

Exit 2 means `mmdc` is not on `PATH`. Stop. Say the diagram is unchecked.

Done when the script exits 0, or the draft has no mermaid block.

## 6. Self-check

Load [assets/section-rubric.md](assets/section-rubric.md). Cut and rewrite until every check for the chosen shape passes.

Done when the rubric passes. Return the path and the title line.
