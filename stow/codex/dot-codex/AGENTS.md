# My User-Level AGENTS.md

## Working agreements

- Ask for confirmation before adding new production dependencies.
- When writing commit messages:
    - Limit title <= 50 chars and wrap body at 72 chars.
    - Use the "Conventional Commits 1.0.0" spec.
- Use `shellcheck`.
- Do NOT under ANY circumstances destroy or mutate infrastructucture by invoking tools or APIs (e.g. `aws rds delete-db-instance`, `terraform apply`, `npx wrangler delete`, `curl -X DELETE`).  Make full use of tools/MCPs/APIs to query in a read-only manner (e.g. `terraform show`, `aws ec2 describe-instances`); be mindful of rate-limiting.
- Save handoffs to `/tmp/handoffs/YYYYMMDD-<kebab-case-topic>.md` using the local date; create the directory if needed and never overwrite an existing file.

## Instruction Discovery

At session start find every `AGENTS.md` from current working directory up to
filesystem root, including this file. Read all found files. Apply broadest
first, then narrower files. Deeper instructions add to or override parent
instructions.

If asked where instructions came from, list every `AGENTS.md` found in ancestor
chain.

