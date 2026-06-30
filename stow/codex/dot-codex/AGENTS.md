# My User-Level AGENTS.md

## Working agreements

- Ask for confirmation before adding new production dependencies.
- When writing commit messages:
    - Limit title <= 50 chars and wrap body at 72 chars.
    - Use the "Conventional Commits 1.0.0" spec.
- Use `shellcheck`.
- Do NOT under ANY circumstances destroy or mutate infrastructucture by invoking tools or APIs (e.g. `aws rds delete-db-instance`, `terraform apply`, `npx wrangler delete`, `curl -X DELETE`).  Make full use of tools/MCPs/APIs to query in a read-only manner (e.g. `terraform show`, `aws ec2 describe-instances`); be mindful of rate-limiting.

## Instruction Discovery

At session start find every `AGENTS.md` from current working directory up to
filesystem root, including this file. Read all found files. Apply broadest
first, then narrower files. Deeper instructions add to or override parent
instructions.

If asked where instructions came from, list every `AGENTS.md` found in ancestor
chain.

<!-- context7 -->
Use Context7 MCP to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service -- even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer -- your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Always start with `resolve-library-id` using the library name and the user's question, unless the user provides an exact library ID in `/org/project` format
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question). Use version-specific IDs when the user mentions a version
3. `query-docs` with the selected library ID and the user's full question (not single words)
4. Answer using the fetched docs
<!-- context7 -->
