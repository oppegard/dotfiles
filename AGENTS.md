# Repository Instructions

These are my dotfiles. See @README.md.

## CI
Lints enforced on this codebase via `hk`/git hooks:

- `secrets`: Runs `gitleaks` over the working tree with repo config and redacted output.
