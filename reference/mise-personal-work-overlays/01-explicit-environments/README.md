# 01: explicit Mise environments

The base `mise.toml` is a complete personal default. `mise.work.toml`
merges when Mise is invoked with `-E work` and replaces the source for the
Codex and Git identity targets.

```sh
mise -C . bootstrap dotfiles apply
mise -C . -E work bootstrap dotfiles apply
```

In production, the work source can point into a private checkout. The public
base only defines target ownership; no employer value or policy needs to live
here. Because the selected complete file always lands at
`~/.codex/config.toml`, the ChatGPT desktop app uses it without a special
launch command.
