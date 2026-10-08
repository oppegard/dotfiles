# Working agreements

- Ask before adding production dependencies.
- Keep infrastructure tools and APIs read-only. Never mutate or destroy
  infrastructure. Respect API rate limits.
- Merge a PR only with my approval. Include the PR number in the final
  merge commit title, e.g. `feat(topic): descriptive (#7)`. Preserve the
  `(#<PR number>)` suffix when a skill or tool supplies or rewrites the title.
- Before implementing a significant change, write a plan and get approval.
- At session start, read every `AGENTS.md` from the working directory
  through the filesystem root.
- Use `request_user_input`, when available, for material decisions that
  repository context does not resolve. Proceed on low-risk choices.

## Communication

Apply these rules to coding and non-coding tasks:

- Write explanations 80% of the way to ASD-STE100 (Simplified Technical
  English): short sentences, one idea per sentence, active voice, and the
  same word for the same thing.
- Prefer diagrams or images when they make an explanation easier to
  understand. Lead with a diagram when the answer has structure, such as
  relationships, processes, decisions, architecture, flow, state, sequence,
  or dependencies.
- Prefer Mermaid for diagrams. Use ASCII when the destination cannot
  render Mermaid.
- Use prose for simple answers and details a diagram cannot show.

## Task references

Read the relevant sections of [CODING_STANDARDS.md](CODING_STANDARDS.md)
before the corresponding work:

- Significant changes or handoffs: Change workflow.
- Commits, PRs, or worktrees: Git.
- Shell scripts, GitHub, GitHub Actions, or mise: Tools.
- Agile, XP, or consulting guidance: Consulting.
- Migrations: Migration wizard.

<!-- pstack:models:begin -->
# pstack model configuration

Provider-qualified per-role choices. Read the installed pstack provider-dispatch reference before dispatching a configured role. Every documented role remains present. `inherit-parent` and `auto` use the parent model natively and still count as one panel lane.

feature, refactoring: codex:gpt-6.1-sol@high
bug-fix: codex:gpt-6.1-sol@high
perf-issue: codex:gpt-6.1-sol@high
hillclimb: codex:gpt-6.1-sol@high
judgment and prose: codex:gpt-6.1-sol@high
hardest tasks: codex:gpt-6.1-sol@high
how explorer: codex:gpt-6.1-sol@high
how explainer: codex:gpt-6.1-sol@high
why investigators, synthesizer: inherit-parent
reflect tooling, judgment, divergent, synthesizer: inherit-parent
arena runners: codex:gpt-6.1-sol@high, codex:gpt-6.1-sol@high, codex:gpt-6.1-sol@high
arena cross-judge pool: codex:gpt-6.1-sol@high, codex:gpt-6.1-sol@high, codex:gpt-6.1-sol@high
swarm workers: codex:gpt-6.1-sol@high
architect runners: codex:gpt-6.1-sol@high, codex:gpt-6.1-sol@high, codex:gpt-6.1-sol@high
interrogate reviewers: codex:gpt-6.1-sol@high, codex:gpt-6.1-sol@high, codex:gpt-6.1-sol@high
<!-- pstack:models:end -->
