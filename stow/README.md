## HOME-level packages:
From **this** directory (`.stowrc` present):

```
stow 1Password
stow uwsm
```

To simulate before making changes, add `-n` option.

### Git Hooks

The `git` stow package installs a global `pre-commit` hook via Git's
`core.hooksPath` setting. That hook runs `gitleaks` against staged changes
before a commit.

On macOS, `stow/setup.sh` already installs `gitleaks` with Homebrew. On Linux,
install `gitleaks` with your distro package manager before relying on the hook.

The hook will warn and allow the commit if `gitleaks` is missing.

To disable only the global Gitleaks check for a single repo:

```
git config hooks.gitleaks false
```

Repo-local `.git/hooks/pre-commit` scripts still run after the global hook.

### Special Snowflakes:

Rectangle Pro:

https://github.com/rxhanson/RectanglePro-Community/discussions/674#discussioncomment-12308761

When making prefs changes, need to export `RectangleProConfig.json` from app back to this repo. Also, after running `stow rectangle` and relaunching Rectangle Pro, it will rename the symlink (per the GH comment above), so that it's only read once.


## Root-level packages

```
cd @root
sudo stow keyd
```
