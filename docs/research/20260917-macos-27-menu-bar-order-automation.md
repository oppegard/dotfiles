# macOS 27 menu-bar item ordering and dotfiles

Researched 2026-09-17 against macOS 27.0 build 26A428, current Apple
documentation, the local read-only preference state, and first-party source or
documentation for the named third-party tools. No settings, permissions, or
running applications were changed.

## Conclusion

macOS 27 has a supported way to set the order interactively: hold Command and
drag a status item. It does **not** expose a documented CLI command, defaults
key, plist schema, MDM field, AppleScript command, or public AppKit API for
declaring the global order of arbitrary applications' status items.

The practical choices are therefore:

1. Keep the intended order in the dotfiles repository as a checklist and do a
   one-time Command-drag arrangement on each Mac. This is the only
   Apple-supported ordering path.
2. Replay Command-drags with coordinate-based UI automation. This can live in
   a repository, but it is a fragile bootstrap procedure rather than an
   idempotent preference.
3. Use Bartender 7 profiles and automation on macOS 27. Bartender can maintain
   and switch layouts, but its published interface does not make the profile's
   ordered contents a documented text/plist format suitable for direct
   dotfiles ownership.
4. Use a Thaw 3 profile exported as JSON. This is the closest current match for
   keeping the desired item sequence in a dotfiles repository, but Thaw's
   macOS 27 implementation is still a prerelease and needs one-time access to
   Apple's protected menu-bar layout file plus Accessibility permission.

A pure `defaults write` solution should not be adopted for macOS 27.

## Capability matrix

| Method | Can set arbitrary cross-app order on macOS 27? | Dotfiles fit | Support level |
| --- | --- | --- | --- |
| Command-drag | Yes, interactively | Checklist or guided setup | Apple-supported |
| Menu Bar settings / Control Center | No; inclusion and visibility only | Some individual preferences may be scriptable, but not order | Apple-supported UI |
| Managed Menu Extras profile | No; boolean inclusion controls only | Profile-managed, not an order | Apple-supported MDM |
| Public AppKit `NSStatusItem` API | No cross-app reorder API | An app can manage its own item | Apple-supported developer API |
| `NSStatusItem Preferred Position …` defaults | Not reliable on 27 | Do not encode as the solution | Private legacy state |
| Accessibility / synthetic Command-drag | Yes, by replaying UI input | Scriptable but display- and layout-dependent | Supported automation primitives, unsupported workflow |
| Bartender 7 profile | Yes, with current limitations | App-owned profile; switching can be automated | Third-party product |
| Thaw 3 exported profile | Yes, with current limitations | JSON profile can be committed and imported | Open-source prerelease; private macOS mechanism |

## 1. Apple-supported behavior

Apple's macOS 27 user guide explicitly says to hold Command while dragging an
icon to rearrange status menus. It also documents Command-dragging an icon out
of the menu bar to remove it. [Apple: What's in the menu bar on Mac?](https://support.apple.com/guide/mac-help/whats-in-the-menu-bar-mchlp1446/27/mac/27)

The macOS 27 Menu Bar settings surface controls which Apple controls and
applications may appear, including `Show When Active` and `Always Show` modes.
It does not offer an ordered list or an order field. The separate customization
guide documents adding and removing controls through System Settings or Control
Center, again without an order declaration. [Apple: Change Menu Bar settings](https://support.apple.com/guide/mac-help/change-menu-bar-settings-mchlad96d366/27/mac/27)
and [Apple: Customize the menu bar](https://support.apple.com/guide/mac-help/customize-the-menu-bar-mchl4af84660/27/mac/27)

Apple's device-management payload reaches the same boundary. `ManagedMenuExtras`
provides booleans for named Apple extras and delay values, but no list/index for
ordering them. [Apple Device Management: ManagedMenuExtras](https://developer.apple.com/documentation/devicemanagement/managedmenuextras)

The public developer API is also narrower than the requested operation:

- `NSStatusBar` can create and remove status items owned by the calling app; it
  has no method for enumerating or reordering other apps' items. [Apple:
  `NSStatusBar`](https://developer.apple.com/documentation/appkit/nsstatusbar)
- `NSStatusItem` exposes visibility, length, appearance, behavior, and an
  `autosaveName`, but no public position or order property. [Apple:
  `NSStatusItem`](https://developer.apple.com/documentation/appkit/nsstatusitem)
- `autosaveName` is documented only as a unique name for saving and restoring
  information about that status item. Visibility persistence is public, but the
  storage schema and any position value are not. [Apple:
  `autosaveName`](https://developer.apple.com/documentation/appkit/nsstatusitem/autosavename-swift.property)
  and [Apple: `isVisible`](https://developer.apple.com/documentation/appkit/nsstatusitem/isvisible)

The absence of a reordering member in those public API surfaces, combined with
Apple documenting Command-drag as the ordering action, is the basis for saying
there is no Apple-supported programmatic global-order contract. It is not a
claim that third-party software cannot reproduce the effect using private or
accessibility mechanisms.

## 2. Why the historical plist technique is not a macOS 27 solution

On older releases, AppKit commonly persisted keys shaped like:

```text
NSStatusItem Preferred Position <autosaveName>
NSStatusItem Visible <autosaveName>
```

The exact domain and autosave name belong to each application. A read-only
`defaults find 'NSStatusItem Preferred Position'` on this Mac still finds old
keys in domains for Apple and third-party applications. Their presence does not
show that macOS 27 consumes them: they may be upgrade residue, and several names
are generic (`Item-0`) or instance-like identifiers rather than portable app
identities.

Current macOS 27 evidence points in the opposite direction:

- The live `com.apple.MenuBarAgent` plist on this host contains only two
  analytics values, not a global ordered list.
- The current `com.apple.controlcenter` state contains visibility and
  customization data plus one BentoBox preferred-position key, not a single
  order covering arbitrary app items.
- Apple's installed `MenuBarAgent` binary contains the strings
  `Persisting trailing item positions`, `trailingItemPreferredPositions`,
  `Using legacy NSStatusItemHost preferredPosition`, and `Migrating preference
  ... from user preferences to protected container`. Its code signature has
  private access to the restricted `com.apple.MenuBar` application group. This
  is strong local evidence that macOS 27 moved authoritative ordering out of
  ordinary per-app defaults and into Apple-owned protected state; it is not a
  public schema or API contract.
- MenubarHide's maintainer documents that macOS 27 changed the menu bar to one
  `MenuBarAgent`-owned window, no longer exposes the per-icon windows or
  per-app position keys its layout saver used, and therefore disables its Icon
  Arrangement feature on 27. Its source documentation retains the old
  preferred-position implementation only for macOS 26 and earlier.
  [MenubarHide: macOS 27 and implementation notes](https://github.com/junior-rj/menubar-hide#macos-27)

Even on releases where those keys worked, the local `defaults(1)` manual warns
not to modify a running application's defaults because the app may not observe
the change and may overwrite it. A repository would also have to know each
app's bundle domain, current autosave name, container location, launch timing,
and numeric position semantics. That is machine and application state, not a
stable ordered configuration format.

Do not confuse ordering with spacing. This repository's
[`mise/macos-menubar-spacing.toml.tera`](../../mise/macos-menubar-spacing.toml.tera)
manages `NSStatusItemSpacing` and `NSStatusItemSelectionPadding`; those values
never specify item order. The Menu Bar Spacing developer now says those hidden
spacing settings no longer work on macOS 27 after the menu-bar rewrite.
[Menu Bar Spacing: macOS 27 warning](https://sindresorhus.com/menu-bar-spacing)

## 3. UI automation is possible, but it is not declarative

Apple documents UI scripting through System Events as a way to simulate user
interaction when an app has no scripting command for a task. It requires the
user to grant Accessibility permission to the controlling app and depends on
the inspected UI hierarchy. [Apple: Automating the User Interface](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/AutomatetheUserInterface.html)

For a menu-bar order, the actual operation still needs to behave like the
documented Command-drag. A shell tool such as `cliclick` can hold Command and
emit drag-down, drag-move, and drag-up events, for example with placeholder
coordinates:

```sh
cliclick kd:cmd dd:SOURCE_X,SOURCE_Y dm:TARGET_X,TARGET_Y \
  du:TARGET_X,TARGET_Y ku:cmd
```

The tool's own documentation defines those commands and requires Accessibility
permission for the terminal or parent process. [BlueM/cliclick](https://github.com/BlueM/cliclick)

This is unsuitable as an unattended convergent dotfiles action because source
and target coordinates vary with display geometry, notch, scaling, menu-bar
auto-hide, native overflow, icon widths, app launch order, and which items are
currently running. A failure can click or drag the wrong UI element. If used at
all, it should be a guarded, human-run bootstrap wizard that:

1. checks the exact display setup and ensures all expected menu-bar apps are
   running;
2. previews the expected source and target items without moving anything;
3. asks for confirmation before each Command-drag;
4. stops if an expected item is absent or the layout changes; and
5. finishes with visual verification.

This route adds a dependency and an Accessibility grant, so it should not be
added to this repository without explicit approval.

## 4. Third-party managers

### Bartender 7

Bartender 7 is the current vendor-supported release for macOS 27. Its release
notes say that it can arrange items without moving the mouse, supports profiles
and automations, and exposes App Intents and AppleScript operations for getting,
showing, or clicking items, changing profiles, and toggling the bar. It also
documents current limitations: large profile changes may take time to settle;
some apps such as iStat Menus have compatibility issues; multiple items from
one app have linked visibility; and native-overflow edge cases may flicker.
[Bartender 7 release notes](https://www.macbartender.com/Bartender7/release_notes/)

This makes Bartender a credible layout owner and its named profiles an
automation target. It does not make the profile contents a dotfiles format. The
published interface documents switching profiles, not creating an exact
ordered profile from a supported JSON, plist, or text manifest. Committing or
importing Bartender's entire private preference domain would have the same
schema, version, and machine-state risks as other private plist approaches.

The currently installed preference residue on this host is for Bartender 6.
Bartender's support page assigns Bartender 7 to macOS 27 and Bartender 6 to
Tahoe and Sequoia, so the old installation/state should not be treated as the
27 solution. [Bartender support and version matrix](https://www.macbartender.com/Bartender6/support/)

### Ice, Hidden Bar, and similar tools

These tools traditionally hide items by placing expandable separator items in
the bar, and several depended on the pre-27 item-window/position behavior.
Hidden Bar's maintainer says it cannot reposition another app's menu-bar item
and documents its macOS 27 hiding mechanism as broken pending redesign.
[Hidden Bar manual](https://github.com/dwarvesf/hidden/blob/develop/docs/MANUAL.md)

MenubarHide has adapted hiding to the native macOS 27 overflow control, but it
explicitly disables layout saving/restoring on 27. That makes it useful for
overflow management, not declarative ordering. [MenubarHide](https://github.com/junior-rj/menubar-hide#macos-27)

### Thaw 3

Thaw 3's current macOS 27 prerelease writes Apple's protected layout table
after the user grants access to that specific file (or grants Full Disk
Access). Its release notes warn that some native/Control Center items, multiple
items from one app, iStat Menus, and live-text items still have limitations.
[Thaw 3.0.0-alpha release notes](https://github.com/thaw-app/Thaw/releases)

Unlike Bartender's documented interface, Thaw's source defines a versioned
JSON profile export containing an ordered `itemOrder` per section and supports
importing the exported JSON. The project describes profiles as importable and
exportable and supports switching profiles through its automation surface.
[Thaw source and profile documentation](https://github.com/thaw-app/Thaw)

That makes an exported Thaw profile the best current *file-shaped* candidate
for this repository. It is still app-owned configuration rather than an Apple
contract: item identifiers can change across apps or OS releases, profile
import is currently an app UI operation, and applying it relies on private
macOS 27 state. Do not symlink or copy Apple's protected file itself.

## 5. What the screenshot establishes

The screenshot is a mixed status-menu area rather than one application's
toolbar. The chevron-like control at the left is consistent with macOS 27's
native overflow indicator: Apple says macOS 27 dynamically hides items when
space is insufficient and replaces them with a compact overflow indicator.
[Apple: What's new for enterprise in macOS 27](https://support.apple.com/en-us/148830)
MenubarHide independently describes the 27 overflow item as the native `«`
control. [MenubarHide: macOS 27](https://github.com/junior-rj/menubar-hide#macos-27)

At the right, Control Center and the date/time are Apple-owned areas documented
by Apple. The intervening icons include status items and possibly controls
added from Menu Bar settings or Control Center. Their exact owning apps should
not be inferred from glyphs alone. That mixed ownership is the important part:
no individual app's supported preference domain owns the global sequence.
[Apple: desktop, menu bar, and Dock](https://support.apple.com/guide/mac-help/desktop-menu-bar-and-dock-mchlws12345m2/27/mac/27)

## Recommendation for this repository

For the lowest-maintenance solution, keep the desired order as a human-readable
manifest or checklist, then perform the supported Command-drag once during
bootstrap. A small verification helper could record a screenshot or ask the
user to confirm the visible order, but it should not write private preferences.

If exact automatic restoration is worth a third-party dependency, evaluate
Thaw 3's exported JSON profile first, because it can encode the ordered item
identifiers in a reviewable repository file. Treat this as an experimental,
permissioned integration until the macOS 27 release matures. Bartender 7 can
also own and switch layouts, but do not treat its full preferences as a
supported portable format unless the vendor publishes such a contract.

If neither manual setup nor app-owned profiles is acceptable, the remaining
option is a confirmation-gated UI-automation wizard. It can encode the desired
sequence and guide/replay the human-only steps, but it should be explicitly
display-specific, fail closed, and verify the final bar rather than claim
declarative convergence.
