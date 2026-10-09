# Coding standards

## Change workflow

### Plan lifecycle

1. Write each plan to a Markdown file before you present it.
   Use the project's existing `docs/plans/` or `doc/plans/` directory.
   If neither exists, create `docs/plans/`.
   Name the file `YYYYMMDD-<kebab-case-topic>.md`.
   Use the local date. Do not overwrite an existing file.
2. Include the proposed changes, the reasons, and a task checklist.
   Get approval before you implement a significant change.
3. Keep the plan file current until you publish the plan in a PR comment.
   During this stage, the file is the source of truth.
4. Put the complete plan and current checklist in a separate PR comment
   titled `Plan: <Plan Title>`. Read the saved comment to confirm that
   both are present. Add a link to this comment in the PR description.
5. After this check, the comment is the source of truth for both the human
   and the agent. Delete the plan file. If Git tracks the file, include its
   deletion in the PR.
6. Read the comment before you continue work. Edit that same comment when
   the plan, decisions, or progress change. Update the main PR description
   when the scope changes.

If publication fails, keep the plan file current until you can verify the
saved comment. If the file was deleted before publication, recover its
latest contents from Git history.

When asking permission only to write the plan, use:
“Execute writing of plan to markdown at <path>?”
That permission covers writing the document. It does not approve its contents.

Save handoffs in the project's existing `docs/handoffs/` or `doc/handoffs/`.
If neither exists, create `docs/handoffs/`. Use
`YYYYMMDD-<kebab-case-topic>.md`, the local date, and preserve existing files.

## Git

Use Conventional Commits 1.0.0. Limit titles to 50 characters and wrap
bodies at 72 characters. Explain what changed and why in the body.

Keep the main PR description concise. For planned changes, follow the
Plan lifecycle in Change workflow.

You may create worktrees under `~/src/worktrees/<repo>/YYYYMMDD-<topic>`.
Report the exact path when creating one.

## Tools

Use these tools when available:

- Shell scripts: `shellcheck`.
- GitHub: `gh`.
- GitHub Actions: `jactionlint`.
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
