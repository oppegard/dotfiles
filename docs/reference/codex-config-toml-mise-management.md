# Managing Codex config.toml with mise

Research date: 2026-09-09

## Recommendation

Do **not** put the complete live `~/.codex/config.toml` under shared source
control or mise's new automatic tracking/sync. Keep work and personal Codex
configurations independent for now. The amount of genuinely portable Codex
configuration is too small to justify continually reconciling a file that the
client and desktop integrations also treat as mutable local state.

If a future requirement makes one generated configuration valuable, use a
mise `template` with an explicit `MISE_ENV=work` or `personal` selection, and
treat its output as entirely declarative. Do not combine that with normal
Codex-managed plugin/marketplace/project state. This is a deliberately
different operating model, not a low-risk incremental improvement.

## Local audit

The currently live file is a symlink to the work-only checkout
`../src/dotfiles-work/adc/dot-codex/config.toml`. It is 630 lines with 68
absolute-path `[projects.*]` entries, 27 `[plugins.*]` entries, and seven
`[mcp_servers.*]` entries. Those project entries encode trusted locations;
they are not portable settings. The committed personal template has two
`[marketplaces.*].last_updated` values, evidence of the churn the question
identified.

The file also contains machine/application paths (notification and desktop
integration commands, the installed app's runtime/cache paths, and MCP
launch commands) and plugin/app enablement. These need to follow what is
installed and authorized on each machine. In contrast, a small set of scalar
preferences such as a default model, reasoning effort, approval policy, and
sandbox mode might be meaningfully shared.

OpenAI documents `projects.<path>.trust_level` as a per-project/worktree
trust decision, and documents MCP server commands, working directories, and
environment forwarding as user-level configuration. Those semantics confirm
that copying the corresponding current values to an unrelated computer would
be misleading at best and unsafe at worst.

## What current Codex supports

Codex has one base user configuration at `~/.codex/config.toml`. It also
loads trusted project-local `.codex/config.toml` layers, but those cannot set
machine-local provider/auth, notification, profile-selection, or telemetry
keys. Project config therefore cannot serve as a portable replacement for
global personal/work defaults. [OpenAI configuration
reference](https://developers.openai.com/codex/config-reference/)

Codex profiles are real overlay layers: `codex --profile NAME` reads the base
file and then `~/.codex/NAME.config.toml`. They are useful for an intentional
per-invocation mode such as `deep-review`; they do **not** provide an include
mechanism for independently maintained `common.toml` plus `work.toml` and
`personal.toml`, nor do they automatically choose a machine identity.
[OpenAI advanced configuration](https://developers.openai.com/codex/config-advanced/)

There is no documented user-config `include`/import feature that would allow
Codex itself to merge a checked-in common TOML fragment with a host-local
fragment. Any such merge would have to be performed outside Codex and would
produce one complete output file.

## What mise 2026.9.3 adds—and why it is not the fit here

The new `mode = "track"` leaves a live file in place, checkpoints it, and can
run a `history-watch` service to save subsequent edits. With a private Git
origin it can also synchronize those checkpoints between machines. The
feature is useful for application configurations edited in place, but its
author explicitly advises selectively tracking exact files and excluding
constantly rewritten session state. [mise dotfiles
documentation](https://mise.jdx.dev/dotfiles.html), [feature
announcement](https://jdx.dev/posts/2026-09-07-dotfiles-that-save-themselves/)

`track` variants can select whole alternate contents by operating system or
mise profile, including a `work` profile. They choose a complete version of a
path; they do not merge TOML tables or protect selected tables from Codex
writes. A watcher would therefore record project approvals, marketplace
timestamps, app/plugin changes, and any accidental temporary configuration.
Sync would make those commits available to the other machine. This is exactly
the wrong granularity for this file. [Variants and tracking
rules](https://mise.jdx.dev/dotfiles.html#different-contents-on-different-machines)

mise templates can render a file from `env`, `vars`, and other template
context, and config environments can be selected with `MISE_ENV`, `-E`, or an
early `miserc.toml`. A later template apply overwrites the target. This can
generate work/personal-specific `config.toml` output, but it requires taking
full ownership of that output: direct edits and Codex-written state will be
replaced on the next apply. [mise templates](https://mise.jdx.dev/dotfiles.html#templates),
[mise configuration environments](https://mise.jdx.dev/configuration/environments.html)

mise block edits are intentionally narrow, preserving everything outside
marker comments. TOML's table scoping makes them a poor way to inject the
desired top-level settings into an arbitrary, frequently rearranged Codex
file: a block appended after a table belongs to that table, and duplicating a
table/key is invalid TOML. They are a good feature, but not a safe hidden
merge mechanism here. [mise edit
entries](https://mise.jdx.dev/dotfiles.html#edit-entries)

## Sensible choices

| Choice | Verdict | Why |
| --- | --- | --- |
| Keep the two complete configs separate | **Recommended now** | Avoids false portability and accepts Codex's local state churn. |
| `mise track ~/.codex/config.toml` with sync | No | Synchronizes the exact path-specific and changing state that should remain local. |
| One shared symlinked complete config | No | Existing work symlink demonstrates the resulting accumulation of machine-specific entries. |
| Fully generated template with `MISE_ENV` | Viable only after a deliberate migration | Works technically, but makes configuration regeneration the authority and discards/overwrites unmanaged Codex changes. |
| Codex profiles | Useful for an occasional task mode | They overlay a base config only when explicitly selected; they do not solve personal-vs-work machine state. |

## Lowest-effort shared-defaults policy

1. Leave the live work and personal `config.toml` files unmanaged by mise
   history/sync and continue treating their project, plugin, marketplace,
   desktop, and MCP details as local state.
2. Maintain a short reviewed list—not a generated config—of the few desired
   cross-machine defaults (for example model, reasoning effort, approval
   policy, sandbox policy, and only integrations that are truly installed on
   both). Apply it manually when changing a machine. This is likely a handful
   of lines and avoids introducing a merge/generation lifecycle.
3. Revisit a generated template only if those common defaults become numerous
   or are repeatedly drifting. At that point, first decide which plugin and
   project state must cease being client-managed, then render the *entire*
   file from a common template plus `config.work`/`config.personal` template
   data and use `mise bootstrap dotfiles diff` before every apply.

That policy preserves the useful intent of the new mise feature—explicitly
owning only the state that should travel—without asking it to solve a
structural merge problem Codex does not expose.

## Sources

- [OpenAI: Configuration reference](https://developers.openai.com/codex/config-reference/)
- [OpenAI: Advanced configuration and profiles](https://developers.openai.com/codex/config-advanced/)
- [mise: Dotfiles](https://mise.jdx.dev/dotfiles.html)
- [mise: Configuration environments](https://mise.jdx.dev/configuration/environments.html)
- [jdx: Dotfiles That Save Themselves](https://jdx.dev/posts/2026-09-07-dotfiles-that-save-themselves/)
