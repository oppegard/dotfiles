# Coding standards

## Change workflow

Before implementing a significant change:

1. Create `YYYYMMDD-<kebab-case-topic>.md` in the project's existing
   `docs/plans/` or `doc/plans/` directory. If neither exists, create
   `docs/plans/`. Use the local date. Preserve existing files.
2. Describe the proposed changes, their reasons, and a task checklist.
3. Present the plan for review. Wait for approval before implementation.
4. Update the plan and checklist as work progresses.

When asking permission only to write the plan, use:
“Execute writing of plan to markdown at <path>?”
That permission covers writing the document. It does not approve its contents.

Save handoffs in the project's existing `docs/handoffs/` or `doc/handoffs/`.
If neither exists, create `docs/handoffs/`. Use
`YYYYMMDD-<kebab-case-topic>.md`, the local date, and preserve existing files.

## Git

Use Conventional Commits 1.0.0. Limit titles to 50 characters and wrap
bodies at 72 characters. Explain what changed and why in the body.

For an approved PR merge, include the PR number in the commit title:
`feat(topic): descriptive (#7)`.

For a planned change, end the PR description with a collapsed `<details>`
section titled `Implementation Plan`. Include the approved plan and current
checklist. Keep the main description concise. Update the section as work
progresses. If the plan file was deleted from Git, recover its latest
contents from Git history for that section.

You may create worktrees under `~/src/worktrees/<repo>/YYYYMMDD-<topic>`.
Report the exact path when creating one.

## Tools

Use these tools when available:

- Shell scripts: `shellcheck`.
- GitHub: `gh`.
- GitHub Actions: `actionlint`.
- mise: consult https://mise.jdx.dev/ for current documentation. For
  advanced examples, consult https://github.com/jdx/mise,
  https://github.com/jdx/fnox, and https://github.com/jdx/hk.

## Consulting

For Agile, XP, or consulting guidance, use the
[Pivotal Alumni Codex](https://github.com/alumni-codex/alumni-codex.github.io)
as a resource.

## Migration wizard

When a migration comes up, use `request_user_input`, when available, to offer:

- Create a wizard for manual steps.
- Continue without a wizard.

Honor a choice already made in the conversation. For a wizard, read and
follow `$wizard`. Include only steps the human must perform.
