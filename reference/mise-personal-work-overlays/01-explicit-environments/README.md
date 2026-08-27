# 01: explicit Mise environments

The base `mise.toml` is a complete personal default. `mise.work.toml`
merges when Mise is invoked with `-E work`. For Codex it adds a native work
overlay without replacing the personal base. For Git it replaces only the
identity source.

```sh
mise -C . bootstrap dotfiles apply
mise -C . -E work bootstrap dotfiles apply
codex --profile work
```

In production, the work profile source can point into a private checkout. The
public base only defines the work target path; no employer value or policy
needs to live here. Codex does not accept a default `profile` selector in the
base file, so work selection stays explicit at launch.
