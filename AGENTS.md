# Repository Instructions

These are my dotfiles. See @README.md.

## CI
`mise run lint` runs these `hk.pkl` checks in CI; `hk` also installs Git hooks:

- `gitleaks`: Scans for secrets.
- `newlines`: Checks file endings (excluding Alfred).
- `shellcheck`: Lints shell scripts (excluding Alfred and vendor files).
- `shfmt`: Checks shell formatting (excluding Alfred and vendor files).
- `tombi`: Checks TOML formatting (excluding Tuna's config).
- `yamlfmt`: Checks YAML formatting.
