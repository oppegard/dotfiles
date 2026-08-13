# Vendored macOS-defaults recorder

This directory vendors the unmodified `diff.sh` recorder from
[yannbertrand/macos-defaults](https://github.com/yannbertrand/macos-defaults)
at commit [`ae534d931241dd8c62a813818bcb921c8c9313d8`](https://github.com/yannbertrand/macos-defaults/commit/ae534d931241dd8c62a813818bcb921c8c9313d8).
The upstream project is available under the MIT License; its complete license
is included in [LICENSE](LICENSE).

`diff.sh` must stay byte-for-byte identical to the pinned upstream file. Its
SHA-256 checksum is
`6c06decd82f83356a6bce6f7b84c1f9c5fe6c782e22e8c745069908587b65dfc`.

Run the recorder with:

```sh
mise -C mise run macos-defaults:record
```

Enter a name, change exactly one setting while the script waits, then press a
key. The script writes pre-change and post-change user and `-currentHost`
preference snapshots under `vendor/macos-defaults/diffs/$name` and prints both
diffs. These files are ignored because they can contain private, account-, and
device-specific preference data.

Use the diff only to identify a key. Add it to mise only if its domain and key
are documented by [macos-defaults.com](https://macos-defaults.com/) and the
preference is intentionally managed here.
