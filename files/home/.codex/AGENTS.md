# Working agreements

- Ask before adding production dependencies.
- Keep infrastructure tools and APIs read-only. Never mutate or destroy
  infrastructure. Respect API rate limits.
- Merge a PR only with my approval.
- Before implementing a significant change, write a plan and get approval.
- At session start, read every `AGENTS.md` from the working directory
  through the filesystem root.
- Use `request_user_input`, when available, for material decisions that
  repository context does not resolve. Proceed on low-risk choices.
- Write short sentences. Use active voice, one idea per sentence, and
  consistent terms.

## Task references

Read the relevant sections of [CODING_STANDARDS.md](CODING_STANDARDS.md)
before the corresponding work:

- Significant changes or handoffs: Change workflow.
- Commits, PRs, or worktrees: Git.
- Shell scripts, GitHub, GitHub Actions, or mise: Tools.
- Architecture, flow, state, sequence, or dependency explanations: Diagrams.
- Agile, XP, or consulting guidance: Consulting.
- Migrations: Migration wizard.
