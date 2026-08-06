# Advanced uses of mise dotfiles

Research date: 2026-08-06

## Scope and method

This note looks only for use of mise's native `[dotfiles]` table and its
`mise dotfiles` / `mise bootstrap dotfiles` commands. It excludes generic
dotfiles repositories, repositories that merely use mise for tools, and
`[dotfiles]` tables belonging to other applications.

The date boundary is based on source history, not repository age or search
result dates. Mise introduced native declarative dotfiles in
[v2026.6.6 on 2026-06-13](https://github.com/jdx/mise/releases/tag/v2026.6.6)
and made bootstrap/dotfiles stable in
[v2026.7.4 on 2026-07-09](https://github.com/jdx/mise/releases/tag/v2026.7.4).
Every shortlisted implementation below has a post-2026-06-13 introducing or
migration commit.

The feature's current surface includes whole-file and directory ownership,
`symlink`, `symlink-each`, `copy`, and `template` modes, exclusions, and
marker-delimited partial-file edits. Entries merge through mise's config
hierarchy. The current canonical command is `mise bootstrap dotfiles`; the
top-level `mise dotfiles` spelling used by several July adopters is now a
deprecated compatibility path. See the
[official dotfiles documentation](https://mise.jdx.dev/dotfiles.html).

Evidence ratings:

- **High**: current public config, a post-launch introducing commit, and
  first-party documentation, tests, or detailed rationale.
- **Medium-high**: current public config and a post-launch introducing commit,
  but little independent explanation or validation.
- **Medium**: an interesting current config with post-launch history, but a
  material uncertainty makes it unsuitable as a reference design without
  testing.

## Best examples

| User | Sophisticated pattern | Native feature introduced | Evidence |
| --- | --- | --- | --- |
| [solforged](https://github.com/solforged/dotfiles) | Hostname-selected personal/work/server/desktop profiles, profile lockfiles, templates, and shared-directory linking | [2026-06-22 scaffold](https://github.com/solforged/dotfiles/commit/052675373385b9e18826adaa2db5a8943dea0fc5); [2026-06-22 profile split](https://github.com/solforged/dotfiles/commit/3aff4c48cf85c07b79e723ae15fdf61d14f1ab35); [2026-07-07 hostname selection](https://github.com/solforged/dotfiles/commit/a43eb9bc4bcfd45921c1bd8f23895a8e8f743741) | High |
| [frixaco](https://github.com/frixaco/dotfiles) | Gitignored per-machine work overlay plus `os()` / `vars.work` templates and mode selection by ownership | [2026-07-08 migration](https://github.com/frixaco/dotfiles/commit/69bded4c4a94b73cabc0b5ad1d04d143339f31f6) | High |
| [mitchnielsen](https://github.com/mitchnielsen/dotfiles) | Personal-device marker selects a `MISE_ENV=work` overlay; work-only dotfiles remain absent on personal machines | [2026-06-26 adoption](https://github.com/mitchnielsen/dotfiles/commit/868e0f65b98b605939e8de0d3bfd523cf591a8b5); [2026-06-26 expansion](https://github.com/mitchnielsen/dotfiles/commit/3286045659341b73ecc8cd5731369175e8ad764c) | High |
| [jonnyasmith](https://github.com/jonnyasmith/dotfiles) | One manifest across macOS, Linux, WSL, and Windows using platform config layers, templates, copies, and validation tasks | [2026-07-31 migration](https://github.com/jonnyasmith/dotfiles/commit/c99ab5d0d0ad628cd844972d870ededc4c1cd818) | High |
| [david-driscoll](https://github.com/david-driscoll/dotfiles) | Global common config plus macOS, macOS-arm64, and Linux layers; bootstrap explicitly enables platform discovery | [2026-07-26 migration](https://github.com/david-driscoll/dotfiles/commit/4563274712b4d4cdab3837eb1c9268e0f3df1752) | High |
| [ryuheechul](https://github.com/ryuheechul/dotfiles) | Modular `conf.d` phases, partial-file edits, and pre/post-dotfiles hooks around a large XDG-oriented map | [2026-07-01 restructuring](https://github.com/ryuheechul/dotfiles/commit/c52d52f55a1458661b7c49894d20aaba4762b05c) | High, with a destructive-hook caveat |
| [umeruma](https://github.com/umeruma/dotfiles) | Always-on shared allowlist plus macOS overlay; per-file ownership where application directories contain runtime state | [2026-07-10 adoption](https://github.com/umeruma/dotfiles/commit/7ec0126f1585ca538264689f079880fddcf1bd03); [2026-07-10 extraction](https://github.com/umeruma/dotfiles/commit/c71aeb282738e118a1add93e668496345efd5065) | High |
| [boykush](https://github.com/boykush/dotfiles) | Ordered block edits into files mise does not fully own, self-management, and macOS CI convergence checks | [2026-07-12 adoption](https://github.com/boykush/dotfiles/commit/4eaed4bc263a902a65eee3ecf9081ed6774b0342); [2026-07-20 first-party write-up](https://zenn.dev/boykush/articles/8d3f52c1a97b04) | High |
| [jefftriplett](https://github.com/jefftriplett/dotfiles) | Incremental coexistence with Homesick and a documented correction after `symlink-each` traversed live sockets/secrets | [2026-06-17 adoption](https://github.com/jefftriplett/dotfiles/commit/b0a8ab358489c64668a6292d9c64468a394ab776) | High as a migration lesson |

## Detailed patterns

### 1. Host-selected work and personal profiles: solforged

The root map deploys the base config, a rendered `miserc.toml`, separate
`config.personal.toml` and `config.work.toml` files, `conf.d`, and a lockfile
for each profile. It also mixes templates for identity/SSH material with
`symlink-each` for directories shared with local state:
[current map](https://github.com/solforged/dotfiles/blob/4ab436b7acbb84a26b7879b3b88bc742968c220a/mise.toml#L85-L129).

Their first-party architecture notes say `MISE_ENV` is derived from a hostname
switch and may combine reusable profiles such as
`personal,desktop,hyperion`. They also keep a private work overlay as a
separate, gitignored repository that contributes an additive `conf.d` file:
[layering and work-overlay rationale](https://github.com/solforged/dotfiles/blob/4ab436b7acbb84a26b7879b3b88bc742968c220a/AGENTS.md#L36-L67).
The personal profile alone contributes personal-only tools, variables, and
dotfiles:
[config.personal.toml](https://github.com/solforged/dotfiles/blob/4ab436b7acbb84a26b7879b3b88bc742968c220a/.config/mise/config.personal.toml#L1-L19).

Why it is useful: it separates three concerns that are often conflated:
machine identity chooses profiles, profiles merge declarative state, and a
private repo carries non-public work policy without making the public base
aware of private paths.

### 2. Gitignored local work overlay plus templates: frixaco

The shared config defaults `vars.work = false`; a gitignored
`mise.local.toml` changes it to true and may add work-only `[dotfiles]`
entries. The same map uses:

- `template` for files that vary by OS or work status;
- `copy` for files rewritten by their applications;
- whole-directory `symlink` for source trees fully owned by the repo.

See the
[map and mode choices](https://github.com/frixaco/dotfiles/blob/3edbea4fd8cb41439c3f23e486307de9597024f1/mise.toml#L4-L100)
and the
[documented local overlay](https://github.com/frixaco/dotfiles/blob/3edbea4fd8cb41439c3f23e486307de9597024f1/README.md#L209-L233).
The rendered `.zshrc` branches on Linux vs macOS and adds a work-only macOS
initialization:
[template source](https://github.com/frixaco/dotfiles/blob/3edbea4fd8cb41439c3f23e486307de9597024f1/home/.zshrc#L1-L132).

Why it is useful: this is the cleanest compact example of one public config
serving personal and work machines without committing the fact-specific local
overlay.

### 3. Explicit `MISE_ENV=work` selection: mitchnielsen

The `setup` task uses a local marker file to choose between ordinary bootstrap
and `mise -E work bootstrap --yes`:
[selection logic](https://github.com/mitchnielsen/dotfiles/blob/6a958f1fe37a983fc03eb56eda8be52e00ee6c94/mise.toml#L23-L33).
The corresponding
[mise.work.toml](https://github.com/mitchnielsen/dotfiles/blob/6a958f1fe37a983fc03eb56eda8be52e00ee6c94/mise.work.toml#L1-L8)
adds a Kubernetes config and agent commands/skills only on work machines.
The base map also uses `symlink-each` for `~/bin` while linking most config
directories whole:
[base dotfiles](https://github.com/mitchnielsen/dotfiles/blob/6a958f1fe37a983fc03eb56eda8be52e00ee6c94/mise.toml#L129-L190).

Why it is useful: it demonstrates the least magical work/personal split. A
machine-local marker selects a normal mise environment file; the work targets
are absent from the base table rather than templated into empty output.

### 4. True OS layers with ownership-aware modes: jonnyasmith

`.miserc.toml` enables early `auto_env`, which loads `mise.macos.toml`,
`mise.linux.toml`, or `mise.windows.toml`:
[early config](https://github.com/jonnyasmith/dotfiles/blob/8a208b9335759500bcf8f0e08ebe39dc495ec11e/.miserc.toml#L1-L4).
The base `[dotfiles]` table self-manages all global mise config files and uses:

- templates for real OS content differences;
- copies for tools that rewrite config files;
- individual files when the surrounding directory is runtime state;
- plain links when the repo owns the whole target.

See the
[base table](https://github.com/jonnyasmith/dotfiles/blob/8a208b9335759500bcf8f0e08ebe39dc495ec11e/mise.toml#L30-L128),
[macOS-only Karabiner copy](https://github.com/jonnyasmith/dotfiles/blob/8a208b9335759500bcf8f0e08ebe39dc495ec11e/mise.macos.toml#L15-L21),
and
[Windows-only PowerShell and Terminal targets](https://github.com/jonnyasmith/dotfiles/blob/8a208b9335759500bcf8f0e08ebe39dc495ec11e/mise.windows.toml#L1-L11).
The repo also validates that every declared source exists and that all global
mise layer files are represented in `[dotfiles]`:
[validation task](https://github.com/jonnyasmith/dotfiles/blob/8a208b9335759500bcf8f0e08ebe39dc495ec11e/mise.toml#L583-L644).

Why it is useful: this is the most complete public example found for one
native mise setup spanning macOS, native Linux, WSL, and native Windows.

### 5. OS and architecture layers around a global config: david-driscoll

This repo treats `.config/mise/config.toml` as global and the root
`mise.toml` as repo-local. It layers `config.macos.toml`,
`config.macos-arm64.toml`, and `config.linux.toml`; its installer exports
`MISE_AUTO_ENV=1` before trusting or bootstrapping so the platform files are
actually present during the run:
[architecture](https://github.com/david-driscoll/dotfiles/blob/f64e581c9137c76030a7a584dd1939cbca34c3f6/README.md#L132-L184)
and
[installer activation](https://github.com/david-driscoll/dotfiles/blob/f64e581c9137c76030a7a584dd1939cbca34c3f6/install.sh#L167-L190).

The shared table uses `symlink-each` for `~/.ssh`, preserving live
`known_hosts`, control sockets, and host keys beside managed entries:
[global config](https://github.com/david-driscoll/dotfiles/blob/f64e581c9137c76030a7a584dd1939cbca34c3f6/.config/mise/config.toml#L93-L124).
Linux-only targets live in the platform file rather than carrying a fictitious
per-entry `os` field:
[Linux layer](https://github.com/david-driscoll/dotfiles/blob/f64e581c9137c76030a7a584dd1939cbca34c3f6/.config/mise/config.linux.toml#L1-L50).

Why it is useful: it shows that platform and architecture are config-loading
concerns, while `[dotfiles]` remains an additive table of concrete targets.

### 6. Modular phases, partial edits, and hooks: ryuheechul

The global config is split into ordered `conf.d` files for repos, dotfiles,
tools, tasks, and macOS defaults. The dotfiles phase includes a large native
map, a `symlink-each` entry for a shared plugin directory, and guarded pre/post
hooks:
[whole-file map and hooks](https://github.com/ryuheechul/dotfiles/blob/3dfae0916b4c46a57a688bf640553ef6254dc38e/mise/home/conf.d/20-dotfiles-symlinks.toml#L1-L124).
A separate entry owns only a generated include block inside `.gitconfig`:
[partial-file block edit](https://github.com/ryuheechul/dotfiles/blob/3dfae0916b4c46a57a688bf640553ef6254dc38e/mise/home/conf.d/25-dotfiles-edits.toml#L1-L13).

Why it is useful: it demonstrates how the native table merges across
`conf.d`, and when a marker-delimited edit is preferable to owning a complete
file.

Caveat: its `pre-dotfiles` hook runs `rm -rf` on a fixed allowlist of
pre-existing real application paths. That may be deliberate in this repo, but
it is not a safe pattern to copy without backups and a much stronger ownership
check.

### 7. Shared allowlist plus platform overlay: umeruma

Early config sets `auto_env = true` and an always-on `env = ["dotfiles"]` so a
dedicated `mise.dotfiles.toml` merges everywhere, while `mise.macos.toml`
contributes only macOS targets:
[early config](https://github.com/umeruma/dotfiles/blob/8b7025a1adee30f08fa84891396836b60dde787d/.miserc.toml#L1-L10).

The shared allowlist links whole static trees, but links only individual files
inside Herdr, Lazygit, and Micro directories that also receive runtime writes:
[shared map](https://github.com/umeruma/dotfiles/blob/8b7025a1adee30f08fa84891396836b60dde787d/mise.dotfiles.toml#L1-L39).
The macOS layer applies the same rule to Hammerspoon and Karabiner so Spoons
and automatic backups remain local:
[macOS map](https://github.com/umeruma/dotfiles/blob/8b7025a1adee30f08fa84891396836b60dde787d/mise.macos.toml#L62-L68).

Windows is an explicit boundary rather than a false success: the repo's deploy
task uses native mise dotfiles on Unix and PSDotFiles on Windows:
[deploy task](https://github.com/umeruma/dotfiles/blob/8b7025a1adee30f08fa84891396836b60dde787d/mise.toml#L5-L48).

Why it is useful: it is a strong example of designing ownership around where
applications put mutable state, while being honest about the platform where a
different mechanism is still used.

### 8. Partial-file ownership plus convergence CI: boykush

Instead of owning all of `.zshrc`, this setup declares three ordered block
edits for mise activation, zoxide, and Starship. It similarly owns only one
MCP block inside Codex's global config:
[block entries](https://github.com/boykush/dotfiles/blob/ebb9c00f96ad914c501b2d18e60ffeffdf9e34c0/mise/config.toml#L105-L150).

Its macOS GitHub Actions job applies the real map in an ephemeral home, runs
bootstrap again, then requires `mise bootstrap dotfiles status --missing` to
pass:
[convergence workflow](https://github.com/boykush/dotfiles/blob/ebb9c00f96ad914c501b2d18e60ffeffdf9e34c0/.github/workflows/mise-bootstrap.yml#L42-L70).
The author explains both choices in a dated first-party article, including why
the generic shell-activation bootstrap feature could not preserve the desired
ordering:
[2026-07-20 write-up](https://zenn.dev/boykush/articles/8d3f52c1a97b04).

Why it is useful: it is the clearest evidence that a user is treating the
feature as testable desired state rather than as a one-time link script.

### 9. Coexistence migration and a `symlink-each` failure mode: jefftriplett

This config deliberately coexists with an existing Homesick castle. It points
`dotfiles.root` at the castle's `home/` tree so mise and Homesick can target
the same paths during migration:
[migration config](https://github.com/jefftriplett/dotfiles/blob/462ae7fb66ad8648cd239acacbf4ada0f78ebe7f/mise.toml#L1-L61).

More importantly, it records a concrete design correction: using
`symlink-each` for broad live config trees descended into iTerm2 sockets and
secrets, so the current map names each immediate child instead:
[failure note and replacement](https://github.com/jefftriplett/dotfiles/blob/462ae7fb66ad8648cd239acacbf4ada0f78ebe7f/mise.toml#L62-L115).

Why it is useful: it is evidence that `symlink-each` is not automatically the
safe answer for a mixed directory. The source tree's shape and the target
application's runtime writes determine whether the walk is appropriate.

## First-party publication and social search

The strongest non-repository evidence found was boykush's
[2026-07-20 Zenn article](https://zenn.dev/boykush/articles/8d3f52c1a97b04),
which links to the author's own repository and explains the migration,
partial-file blocks, status checks, and CI. It is first-party and dateable.

Date-bounded searches for first-party posts on X, Mastodon, and Bluesky did
not return a result that could be both opened and tied to a native
post-June-2026 implementation. Search snippets alone were not treated as
evidence.

## Promising but lower-confidence leads

- [brizdotdev/dotfiles](https://github.com/brizdotdev/dotfiles/blob/89f63bcbc30df37d1034b897a1575ab9672255b9/linux/config/mise/miserc.toml#L1-L26)
  uses Tera in `miserc.toml` to select Linux/macOS vs Windows target paths.
  The platform conditional was introduced on
  [2026-08-01](https://github.com/brizdotdev/dotfiles/commit/a72207d4dc7d0e9016c3636373ed7723445e4daa).
  Evidence is medium-high: the source is clear, but no first-party validation
  or cross-platform test was found.
- [Jelenkee/dotfiles](https://github.com/Jelenkee/dotfiles/blob/5bab1c17876e60da968c767521dbfad30d450d28/mise.toml)
  maps the repository root into `~` with `symlink-each` and exclusions, added
  on
  [2026-07-27](https://github.com/Jelenkee/dotfiles/commit/a38025efc121d5a2d107fbc90fa59efbb350c313).
  It is compact and interesting, but `dotfiles.root = "{{ pwd }}"` makes the
  result sensitive to settings-template and working-directory semantics; no
  validation evidence was found. Treat it as an experiment, not a reference.

## False-positive exclusions

- Pre-feature content was excluded even when it discusses mise and dotfiles.
  Examples include the
  [2026-02-11 mise + chezmoi article](https://tommeurs.nl/posts/dotfile-management-mise-chezmoi/)
  and the
  [2026-05-31 yadm + mise article](https://zenn.dev/vim_jp/articles/2ee400a66228a7).
  They use mise for tool management alongside another dotfile manager, not
  mise's native feature.
- Repositories with `[dotfiles]` belonging to another schema were excluded.
  Examples include
  [Capsule's `[dotfiles]`](https://github.com/rachartier/dotfiles/blob/d9198b19d812a008da91e8409e8fe5be0beb710b/.config/capsule/config.toml)
  and
  [Mimic's `[[dotfiles]]`](https://github.com/binbandit/mimic/blob/832b54caa1b6411106423150967614942df6b077/examples/multi-host/mimic.toml).
- Atuin configuration commonly contains `[dotfiles] enabled = true`; that is
  an Atuin setting, not a mise mapping.
- Mise's own docs, source, tests, and example snippets establish behavior but
  were not counted as external user adoption.
- The current `oppegard/dotfiles` repository was excluded from the user list
  because it is the requester's own implementation, not an independent
  example.
- A `dotfiles.root` setting without active `[dotfiles]` entries was not enough
  to qualify.

## Practical synthesis

The strongest patterns separate two different kinds of variation:

1. **Which targets exist on this machine?** Use config layers: a
   `mise.<environment>.toml` work/personal profile or a
   `config.<platform>.toml` / `mise.<platform>.toml` OS layer.
2. **How does one target's content vary?** Use a `template` with `os()`, vars,
   or environment input.

Other repeated lessons:

- Use `copy` when the application atomically rewrites its config file.
- Link a whole directory only when the repo owns the whole tree and new files
  should flow back into source control.
- Use `symlink-each` or explicit per-file entries when managed files must
  coexist with runtime state, but do not point it at an unbounded live tree
  without testing what it traverses.
- Keep untracked work identity and secrets in a local profile or private
  additive overlay rather than in the public base.
- Use block edits when mise should own only a small, ordered fragment of a
  file.
- Add a convergence test: apply, apply again, then require
  `mise bootstrap dotfiles status --missing` to succeed.

For a work/personal plus macOS/Linux setup, the most defensible composite is:

- early `auto_env` for OS config discovery;
- a base cross-platform `[dotfiles]` table;
- OS files for platform-only targets;
- an explicitly selected `personal` or `work` mise environment for identity
  and organization-only paths;
- templates only where the same target genuinely needs different content;
- local/private overlays for material that must not enter the public repo.
