# Section rubric

Run the checks for the chosen shape. Also run "Every body". Fix the draft and run the checks again until they pass.

## Every body

- Every angle-bracket hint is replaced with a fact. `TBD` and `TODO` are gone.
- Command output is text the task printed. The command name is the line above the fence.
- These words are gone: `great`, `amazing`, `significantly`, `best-in-class`, `powerful`.
- A quote matches its source character for character.
- When the draft has a mermaid block, `scripts/check-mermaid.sh` exited 0 and each edge label follows the quoting rule in step 5.

## Template

- Every heading in the repository template has a filled body.
- The draft uses only the template's headings.

## Short form

- The sections are TL;DR, Implementation, and How to test, in that order.
- The body is under 40 lines.
- TL;DR is 2 to 4 sentences.
- Implementation names each changed file and the intent for that file.
- How to test has at most 5 steps. Each step has an action and an expected result.
- Each why-claim cites a source you can open.

## Long form

- The headings match [pr-body-template.md](pr-body-template.md), in that order. Diagrams may be absent when the template's omit rule applies.
- TL;DR is 2 to 4 sentences.
- Problem has at most 6 bullets and at most 3 verbatim quotes.
- Approach is a table, or 3 to 7 bullets, or the single line `Additive. See Implementation.`
- Implementation states intent for each file. More than five files use a table.
- There are at most two mermaid blocks. A third block shows a relationship the other two do not.
- Trade-offs name an option chosen and an option rejected. A mechanical change has 1 or 2 bullets. Any other change has 3 to 5.
- Validation shows real task output.
- A behavior change has the scenario table. A diff with no behavior change may skip it. Trade-offs then names that skip.
- How to test has at most 5 steps. Each step has an action and an expected result.
- Each why-claim cites a source you can open.
- A body over 250 lines is cut until it is at most 220 lines.
