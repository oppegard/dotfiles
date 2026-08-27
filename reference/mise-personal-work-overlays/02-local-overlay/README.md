# 02: gitignored machine-local overlay

`mise.toml` owns common targets but intentionally does not choose identity.
Copy one profile example to the ignored `mise.local.toml`:

```sh
cp mise.local.personal.toml.example mise.local.toml
# or
cp mise.local.work.toml.example mise.local.toml
mise -C . bootstrap dotfiles apply
```

Mise automatically loads the local file. The selection persists on the
machine, but it is intentionally absent from version control.
