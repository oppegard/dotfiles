# My User-Level AGENTS.md

## Working agreements

- Ask for confirmation before adding new production dependencies.
- When writing commit messages:
  - Limit title <= 50 chars and wrap body at 72 chars.
  - Use the "Conventional Commits 1.0.0" spec.
  - Use the body to explain what and why vs. how. Assume the code explains the how; the message must explain the context and reasoning.
- Do NOT under ANY circumstances destroy or mutate infrastructucture by invoking tools or APIs (e.g. `aws rds delete-db-instance`, `terraform apply`, `npx wrangler delete`, `curl -X POST`).  Make full use of tools/MCPs/APIs to query in a read-only manner (e.g. `terraform show`, `aws ec2 describe-instances`); be mindful of rate-limiting.
- Do not ever merge a PR. I will directly instruct you if I want different behavior.
- You may create worktrees under `/tmp/worktrees/<git-repo-name>/YYYMMDD-kebab-case-topic>`.
- When asked for guidance regarding Agile, XP, or Consulting, use the [Pivotal Alumni Codex](https://github.com/alumni-codex/alumni-codex.github.io) as a resource.
- Tools to use when available:
  - `shellcheck`
  - `gh` for GitHub and `actionlint` for GH Actions
  - `mise` - query https://mise.jdx.dev/ for latest docs, as the featureset changes weekly. For examples of advanced usage of mise itself, check https://github.com/jdx/mise, https://github.com/jdx/fnox, and https://github.com/jdx/hk.

## Planning Mode Workflow
- Before implementing any significant change, always create a `YYYMMDD-kebab-case-topic.md` file in the project's `doc{s}/plans/` directory using the local date; create the directory if needed and never overwrite an existing file.
- If you request user input to execute the plan but "execution" means writing the markdown file, specifically ask for user input with a promp "Execute writing of plan to markdown at <path>?". I don't want ambiguity of when "execute" means writing the markdown file, or actually executing the work described by a plan.
- The plan must outline the proposed changes, the reasoning behind them, and a checklist of tasks to be completed.
- Update the markdown file as progress is made.
- Do not begin coding until the plan has been reviewed and approved.
- If creating a "handoff" doc, save it to `doc{s}/handoffs/YYYYMMDD-<kebab-case-topic>.md` using the local date; create the directory if needed and never overwrite an existing file.
- PRs:
  - When creating or updating a PR for a planned change, include the approved plan and current task checklist at the end of the PR description in a collapsed `<details>` section titled "Implementation Plan".
  - Keep the main PR description concise and update the collapsed plan as work progresses.
  - If the plan file was deleted for git, recover its latest contents git history and post/update the PR's "Implementation Plan".

## Instruction Discovery

At session start find every `AGENTS.md` from current working directory up to
filesystem root, including this file. Read all found files. Apply broadest
first, then narrower files. Deeper instructions add to or override parent
instructions.

## User Input

When available, use `request_user_input` for material decisions unresolved by
repository context. Ask 1–3 concise questions with explicit options. Proceed
autonomously on low-risk choices.

## Migration Wizard Choice

When the user brings up a migration, offer a choice with `request_user_input`
when available: **Create a wizard for manual steps** (invoke `$wizard`)
or **Continue without a wizard**. If the user has already chosen either path,
follow that choice without asking again. For a wizard, read and follow the
`$wizard` skill and include only steps the human must perform.
