# Karabiner-Elements 17.0.0 upgrade review

Researched 2026-11-28. The installed version was `16.3.0`. Homebrew
reported `17.0.0` for the `karabiner-elements` cask. This note is
read-only: it proposes no configuration change.

Sources:

- [v17.0.0 release](https://github.com/pqrs-org/Karabiner-Elements/releases/tag/v17.0.0)
- [Release notes](https://karabiner-elements.pqrs.org/docs/releasenotes/)

## Conclusion

No breaking change affects this repository. The checked-in rule file,
`files/home/.config/karabiner/assets/complex_modifications/intellij-function-keys.json`,
needs no edits. The upgrade needs one manual step in System Settings.

## Breaking changes

| Change | Effect here |
|---|---|
| `karabiner_cli` moved to `/Applications/Karabiner-Elements.app/Contents/Helpers/karabiner_cli`. | None. Nothing in the repository calls `karabiner_cli` or the old `org.pqrs` path. |
| Helper apps moved to `Contents/Helpers`. Maintenance scripts moved to `Contents/Resources`. | None. |
| Inter-process communication changed from UNIX domain sockets to XPC. | Internal only. |

The release notes list no JSON schema change, no new minimum macOS
version, and no driver change.

## Required action after upgrade

1. In System Settings, Background App Activity, enable
   "Karabiner-Elements Privileged Daemons v3".
2. Ignore a one-time "Karabiner-Updater.app can't be opened" error.

The cask has `auto_updates`. The app updates itself. `brew upgrade`
skips it unless you pass `--greedy`.

## Security fixes

- GHSA-rj4j-2pp3-m4ww: a race in local IPC authentication (16.0.0 to
  16.3.0). Running malware could read focused window and UI element
  titles.
- GHSA-3xf6-mj44-3q6g: a race in config-file ownership checks (16.3.0
  and earlier). On a multi-user Mac, one user could see parts of
  another user's config.

## Features to consider

Recommended:

- Expert tab settings now disable each Accessibility monitor
  separately. The rules here use only `frontmost_application_if`.
  Keep frontmost-application monitoring. Disable focused-window and
  focused-UI-element monitoring. `karabiner.json` is not managed here,
  so set this in the UI. Test IntelliJ F1 to F12 after the change.

Automatic benefits:

- Same-timestamp events from QMK and ZMK keyboards are reordered so
  modifier releases come before key presses. This can help the
  Keychron Q1 Pro.
- Key repeat keeps modifiers active, which covers the `fn` + F-key
  mappings.

Not needed now:

- `serial_number`, `transport`, and `device_address` device
  identifiers. The Lofree Flow84 and Keychron Q1 Pro have different
  vendor and product IDs.
- `set_caps_lock_led` and `mouse_motion_and_wheel_to_key`.
- Logitech HID++ button remapping, Shift + keys in Simple
  Modifications, and the `system.ui_language` variable.
