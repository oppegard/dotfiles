# My User-Level AGENTS.md

## Working agreements

- Ask for confirmation before adding new production dependencies.
- When writing commit messages:
    - Limit title <= 50 chars and wrap body at 72 chars.
    - Use the "Conventional Commits 1.0.0" spec.
- Do NOT under ANY circumstances destroy or mutate infrastructucture by invoking tools or APIs (e.g. `aws rds delete-db-instance`, `terraform apply`, `npx wrangler delete`, `curl -X DELETE`).  Make full use of tools/MCPs/APIs to query in a read-only manner (e.g. `terraform show`, `aws ec2 describe-instances`); be mindful of rate-limiting.
- When creating a handoff, save it to `/tmp/handoffs/YYYYMMDD-<kebab-case-topic>.md` using the local date; create the directory if needed and never overwrite an existing file.
- You may create worktrees under `/tmp/worktrees/<git-repo-name>/YYYMMDD-kebab-case-topic>`.
- When asked for guidance regarding Agile, XP, or Consulting, use the [Pivotal Alumni Codex](https://github.com/alumni-codex/alumni-codex.github.io) as a resource.
- Tools to use when available:
  - `shellcheck`
  - `gh` CLI for GitHub
  - `actionlint` for GitHub Actions

## Planning Workflow
- Before implementing any significant change, always create a `YYYMMDD-kebab-case-topic.md` file in the project's `doc{s}/plans/` directory.
- The plan must outline the proposed changes, the reasoning behind them, and a checklist of tasks to be completed.
- Update the markdown file as progress is made.
- Do not begin coding until the plan has been reviewed and approved.

## Instruction Discovery

At session start find every `AGENTS.md` from current working directory up to
filesystem root, including this file. Read all found files. Apply broadest
first, then narrower files. Deeper instructions add to or override parent
instructions.

If asked where instructions came from, list every `AGENTS.md` found in ancestor
chain.
