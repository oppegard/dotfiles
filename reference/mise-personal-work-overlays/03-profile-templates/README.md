# 03: profile-driven templates

The target map exists once in `mise.toml`. Environment files set the profile
and identity values used to render each target:

```sh
mise -C . -E personal bootstrap dotfiles apply
mise -C . -E work bootstrap dotfiles apply
```

This is compact for scalar differences, but real Codex files tend to become a
large conditional template. It also produces independently writable copies,
so edits to the rendered target do not update the template source. The
rendered target is the canonical `~/.codex/config.toml`, which makes this
version compatible with ChatGPT desktop startup.
