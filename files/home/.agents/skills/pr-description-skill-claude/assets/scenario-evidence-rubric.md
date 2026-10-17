# Scenario Evidence

The Scenario Evidence table answers one reviewer question: for each user
promise this PR touches, which test proves it still holds?

This is scenario coverage, not line coverage. A scenario is a flow a user
relies on; if it silently broke, users would notice.

## Table

| # | Scenario (user promise) | Concern | Test proving it | Type |
|---|-------------------------|---------|-----------------|------|
| 1 | <Scenario in the user's words.> | <One or more concerns.> | `<path::test_name>` | unit / integration / e2e |

Rules:

- **Scenario** is in the user's words. Good: "Running `app sync` twice
  leaves the remote unchanged." Implementation words belong in the
  Implementation section.
- **Concern** names the principle the scenario serves. Use the repo's own
  principles when README, CONTRIBUTING, or AGENTS.md states them, and cite
  their names verbatim. Otherwise pick from: correctness, security,
  compatibility, performance, operability, developer experience. Drop the
  column only when no row would add signal beyond correctness.
- **Test** is a real path a reviewer can open, with a test name or line
  range. Several tests for one scenario share a row, separated by `<br>`.
- **Type** is `unit`, `integration`, or `e2e`.
- **One row per scenario**, not per test. Tests of internal helpers stay
  out unless the helper is a user-facing boundary, such as a CLI command
  or public API.
- **Bug fixes** include the regression test that fails without the fix,
  marked `(regression test for #<issue>)`.

## Weak evidence goes in Trade-offs

Some evidence proves less than it appears to. Record these in Trade-offs
with a follow-up, rather than in the table:

- A cross-module change proven only by unit tests on each side. It needs
  one integration test across the boundary.
- A security scenario proven by a test that mocks the boundary it
  asserts. Prove it with a real malicious input.
- A scenario proven only by manual testing.

## Example

A PR that makes `fetch` retry on HTTP 429:

| # | Scenario (user promise) | Concern | Test proving it | Type |
|---|-------------------------|---------|-----------------|------|
| 1 | `fetch` succeeds when the API rate-limits the first two requests | correctness | `tests/fetch_test.go::TestRetryOn429` (regression test for #88) | integration |
| 2 | `fetch` gives up after 5 attempts and prints the last status | operability, developer experience | `tests/fetch_test.go::TestRetryLimit` | unit |
| 3 | A 401 response fails at once, without retry | security | `tests/fetch_test.go::TestNoRetryOnAuthFailure` | unit |

## Skip clause

Omit the table only for one of these cases, and name the case in
Trade-offs:

- Docs-only change.
- Dependency or lockfile bump with no behavior change.
- Pure refactor whose existing tests pass unmodified. Cite the suite that
  ran green; those tests are the evidence.
- No test suite covers the changed surface (config, agent instructions,
  new tooling). List each scenario and how it was checked by hand.
