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

## Mise lock age

`minimum_release_age = "7d"` in `mise.toml` and
`files/home/.config/mise/config.toml` is the wait before a new release can be
locked. Change the wait in those files. The GitHub workflow does not have its
own age.

`mise install --locked` keeps versions already in the lock. `mise lock --bump`
and `mise upgrade` use the wait. A tool option named `minimum_release_age`
overrides the setting for that tool.

The nightly job sets `MISE_SAFE=1`. Safe mode ignores project settings, so the
job reads `settings.minimum_release_age` from each file and exports
`MISE_MINIMUM_RELEASE_AGE` for that lock. The pending probe and
`emergency_tool` pass `--minimum-release-age 0s`, which overrides the setting
and any tool option.

A local `mise lock --bump` can move a locked version backward when that
version is still inside the wait. The nightly job refuses that move. Review
the diff. The key in `files/home/.config/mise/config.toml` is the global mise
setting after bootstrap. Other projects inherit it unless they set their own.
