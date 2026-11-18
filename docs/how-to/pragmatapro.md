# Use PragmataPro in your apps

This PR configures Ghostty and Rex in the repository. It leaves the live
machine unchanged. Apply those settings later through the normal dotfile
and bootstrap process. The IDEA and Obsidian steps remain manual options.
Read the [font explanation](../research/20261028-pragmatapro.md) for the reasons.

## Confirm the family first

Choose `PragmataPro Mono Liga` for the recommended terminal setup. If the
family is missing, install its four TTF styles with Font Book from your
licensed download. Use one format of each family. Restart the affected app
if it does not refresh its font list.

In a terminal, print the [static specimen](../examples/pragmatapro/terminal.txt)
from the repository root:

```sh
cat docs/examples/pragmatapro/terminal.txt
```

The file contains no terminal escape sequences. It does not change settings.
Check operator shapes, alignment, and icons in each app. Move the cursor
through `->` and `===`, then copy the line into a plain-text editor.
The underlying characters must remain unchanged.

## Configure Ghostty

The Ghostty config included in this PR selects the Liga family at size 16:

```ini
font-family = "PragmataPro Mono Liga"
font-size = 16
```

The font enables its programming ligatures by default. Ghostty can match the
family's real Bold, Italic, and Bold Italic styles automatically.

To try curved Git graphs, add:

```ini
font-feature = ss13
```

To add selected keyword badges too, add:

```ini
font-feature = ss15
font-feature = ss18
```

Leave `ss12` and `ss20` off unless their broader substitutions are intentional.
To keep the Liga family but disable programming ligatures, use:

```ini
font-feature = -calt
```

Remove that override to restore the font defaults. It also disables other
contextual forms, so choosing `PragmataPro Mono` is another plain-operator
option. Do not expect `-liga` alone to disable this font's programming ligatures.

Ghostty uses its own configuration format. Its `key = value` lines are not
TOML. Feature overrides apply to fallback fonts too. Invalid tags can be
silently ignored, so compare the specimen after changing them.
[Ghostty font settings](https://ghostty.org/docs/config/reference#font-feature).

## Configure Rex

1. Open **Rex Settings** with **Cmd+,**.
2. Select **Terminal**.
3. Choose `PragmataPro Mono Liga`, Regular, at 16 pt.
4. Leave **Ligatures** on.

These values already match the inspected live settings. There is no verified
Rex control here for arbitrary tags such as `ss13`. Ghostty's feature lines do
not become Rex settings.

### Represent selected appearance settings in mise TOML

This PR includes these values in the repository's existing
`[bootstrap.macos.defaults]` table in
`files/home/.config/mise/config.macos.toml`:

```toml
"com.superlogical.rex" = {
	"Workspace.terminalFontName" = "PragmataPro Mono Liga",
	"Workspace.terminalFontPointSize" = 16.0,
	"Workspace.terminalAllowsLigatures" = true,
}
```

This fragment is part of that existing table. It is not a standalone
Rex config. The family and numeric type were read from your preferences.
The ligature key comes from the installed app, and its UI currently shows on.
Provisioning and running-app reload behavior were not tested. Recheck these
internal keys when Rex changes.

The repository normally manages selected macOS preferences rather than whole
third-party state files. These narrow appearance keys take effect through
the normal bootstrap process when you apply it later. Do not symlink the
whole Rex plist.

### Track bindings separately

Keep server bindings and actions in `~/.config/rex/init.lua`. A future dotfile
mapping could link that directory in the same way as the Ghostty directory.
The installed Lua validator accepts a draft path:

```sh
rex config check /path/to/init.lua
```

To apply an intentional server-config change later, run `rex config reload`
on the server machine. Rex does not watch this file automatically.
The CLI is already on the path inside Rex. Its installed full path is
`/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex`.
[Rex file location and validation](https://www.superlogical.com/rex/docs/customize/config).

## Configure IntelliJ IDEA

### Editor and run/debug console

1. Open **Settings > Editor > Font**.
2. Select `PragmataPro Mono Liga`.
3. Enable **Enable ligatures**.
4. Start at 16 pt and adjust the size by appearance.
5. Open **Typography Settings > Character variants** only for variants you want.

IDEA 2026.1 and newer support editor stylistic sets. Check the font override
under **Editor > Color Scheme > Color Scheme Font** if the editor ignores
the family selection. Use **Show Fonts Used by Editor** to inspect glyph
fallback. Keep the run/debug console's inherited font first. Its separate
override is under **Editor > Color Scheme > Console Font**.
[IDEA font settings](https://www.jetbrains.com/help/idea/settings-editor-font.html),
[color scheme and console settings](https://www.jetbrains.com/help/idea/configuring-colors-and-fonts.html).

### Built-in terminal

Select the family independently under **Settings > Tools > Terminal > Font**.
Start with the default column width and line height. Print the specimen in
that terminal. Confirm ligatures there rather than assuming editor variants
carry over.

The new libghostty engine starts in 2026.3 EAP. Your inspected IDEA 2026.2.3
installation is older. Its renderer and font controls remain JetBrains code
even after the engine changes. Exact arbitrary-feature behavior in the new
terminal remains unverified.
[Terminal settings](https://www.jetbrains.com/help/idea/settings-tools-terminal.html),
[libghostty announcement](https://blog.jetbrains.com/platform/2026/10/jetbrains-terminal-now-uses-ghostty/).

## Choose an Obsidian setup

| Option | Result | When to use it |
| --- | --- | --- |
| Monospace font only | Code and frontmatter use PragmataPro. Prose keeps its current font. | Recommended first choice. |
| Editor-only monospace | Editing uses the monospace family. Reading view keeps its prose font. | Markdown columns and plain-text composition. |
| Text font and monospace font | Both editing and reading use your chosen text family. | An intentional all-monospace notebook. |

### Use PragmataPro for code first

1. Open **Settings > Appearance > Font > Monospace font > Manage**.
2. Choose `PragmataPro Mono Liga`.
3. Keep **Interface font** and **Text font** as they are.

This built-in setting needs no plugin. It is Obsidian's documented control
for code blocks and frontmatter. For explicit code ligatures, copy
[obsidian-code.css](../examples/pragmatapro/obsidian-code.css) into the vault's
snippet folder. It enables only the verified `calt` feature.

### Use monospace only while editing

Keep the Monospace font selection above. Add
[obsidian-editor.css](../examples/pragmatapro/obsidian-editor.css) as a snippet.
It changes the Markdown editor's font and leaves Reading view alone. Themes
may give headings their own fonts.

### Use a monospace notebook throughout

Set **Text font** to `PragmataPro Mono Liga` as well. For symbol-heavy prose,
try `PragmataPro Liga` as the Text font while keeping Mono Liga for code.
The wider symbol family can help reading, but use Mono for space-aligned tables.

### Enable a snippet

1. Open **Settings > Appearance > CSS snippets**.
2. Open the snippets folder with its folder button.
3. Copy the chosen CSS file into that folder.
4. Refresh the snippet list.
5. Enable the snippet.

The usual folder is `.obsidian/snippets/` inside the vault. A vault can choose
another configuration folder. Install the font on each device where you
want it. Do not put purchased desktop font binaries in a published vault or
embed them in CSS. No vault or snippet was changed by this PR.

Obsidian measures its text size in pixels. Ghostty and IDEA use points.
Match their apparent size rather than copying the same number everywhere.
Syntax highlighting can split text into spans and affect ligature shaping.
Custom themes can override the supplied CSS, so compare editing and Reading
view in your actual vault.
[Obsidian settings](https://obsidian.md/help/settings),
[CSS snippets](https://obsidian.md/help/Extending+Obsidian/CSS+snippets).
