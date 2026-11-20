<!--
  Fill each <placeholder> from the step-1 inputs. Every section header
  stays; a section's body may shrink to one line on a small PR. The PR
  title goes in the reply, not in this file.
-->

## TL;DR

<2-4 sentences: what changed, why now, and the outcome a reviewer can
observe.>

> [!NOTE]
> <Optional: the one fact a reviewer needs first, such as a linked
> issue, a follow-up PR, or a required deploy order.>

## Problem

<Up to 6 bullets of observed failures or limits, each with evidence:
an issue link, a `file:line` permalink, a log excerpt, or a prior PR.>

- <Observed failure, with evidence.>
- <Observed failure, with evidence.>

## Approach

<3-7 bullets or a table of the fixes. For a purely additive PR, write
"Additive change; see Implementation.">

| # | Fix | Why (when non-obvious) |
|---|-----|------------------------|
| 1 | <One-line fix.> | <Reason, with evidence.> |

## Implementation

<One line per file, or a table. State intent and scope, not the diff.
Permalink format: https://github.com/<owner>/<repo>/blob/<sha>/<path>#L<a>-L<b>>

- **`<path>`**: <intent; what was deliberately left alone.>

## Diagrams

<Omit this section when no relationship in the PR is non-trivial.
Nodes and edges come from this PR: real files, functions, jobs, or
components.>

<One-sentence legend: what the diagram shows and where to look first.>

```mermaid
<validated block>
```

## Trade-offs

<1-2 bullets for a mechanical PR; 3-5 for a cross-cutting one.>

- **<Decision>.** Chose <option> over <option> because <reason>.
- **<Pre-existing issue left in place>.** <Why it belongs in a separate
  PR.>

## Validation

`<command>`:

```
<verbatim output>
```

<details><summary><Full output of command (N tests)></summary>

```
<verbatim transcript>
```

</details>

### Scenario Evidence

<Required for a behavior change; see assets/scenario-evidence-rubric.md.>

| # | Scenario (user promise) | Concern | Test proving it | Type |
|---|-------------------------|---------|-----------------|------|
| 1 | <Scenario in the user's words.> | <Concern.> | `<path::test_name>` | unit / integration / e2e |

## How to test

- [ ] <Action> → <expected observation>.
- [ ] <Action> → <expected observation>.
