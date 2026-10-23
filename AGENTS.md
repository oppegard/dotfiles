# Repository Instructions

These are my dotfiles. See @README.md.

## CI

`mise run lint` runs these `hk.pkl` checks in CI; `hk` also installs Git hooks:

- `gitleaks`: Scans for secrets.
- `go_fmt`: Checks Go formatting.
- `go_vet`: Vets Go code in the repository module.
- `jactionlint`: Checks GitHub Actions workflows with the pedantic profile.
- `mise`: Checks project mise config formatting.
- `newlines`: Checks file endings (excluding Alfred).
- `rumdl`: Checks Markdown as GitHub-flavored markdown, excluding vendor files. `.rumdl.toml` disables line-length checks and leaves bare URLs as written.
- `shellcheck`: Lints shell scripts (excluding Alfred and vendor files).
- `shfmt`: Checks shell formatting (excluding Alfred and vendor files).
- `tombi`: Checks TOML formatting (excluding Tuna's config).
- `trailing_whitespace`: Checks trailing whitespace.
- `yamlfmt`: Checks YAML formatting.

## Mise Use

Mise evolves quickly: check for the latest features and options at https://mise.jdx.dev/. Whenever possible, encode mise's own settings into its `config.toml` ([reference](https://mise.jdx.dev/configuration/settings.html)); reserve the use of `MISE_` env vars for special case override scenarios.
