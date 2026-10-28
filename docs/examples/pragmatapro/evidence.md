# PragmataPro investigation evidence

These checks describe the 0.903 files inspected on 2026-10-28. They read
font metadata and shape text. They do not modify the font files.

## Recheck file names and coverage

Run with HarfBuzz's `hb-info` installed:

```sh
PRAGMATA_DIR="$HOME/Downloads/PragmataPro0.903"
hb-info --show-family --show-version --show-unicode-count --show-glyph-count \
	"$PRAGMATA_DIR/PragmataProR_0903.ttf"
hb-info --show-family --show-version --show-unicode-count --show-glyph-count \
	"$PRAGMATA_DIR/PragmataPro_Mono_R_liga_0903.ttf"
hb-info --list-features "$PRAGMATA_DIR/PragmataPro_Mono_R_liga_0903.ttf"
```

The inspected Regular results were:

| File | Family | Encoded characters | Glyphs |
| --- | --- | --- | --- |
| `PragmataProR_0903.ttf` | PragmataPro | 18,704 | 20,459 |
| `PragmataPro_Mono_R_liga_0903.ttf` | PragmataPro Mono Liga | 15,734 | 17,509 |

The features include `calt`, `cv01` through `cv05`, and the relevant stylistic
sets. There is no `liga` or `clig` tag. A `dlig` tag exists, but the handbook
assigns the illustrated decorative substitutions to `ss12`. The tags are not
interchangeable.

## Compare the operator shaping

```sh
hb-shape "$PRAGMATA_DIR/PragmataPro_Mono_R_liga_0903.ttf" \
	'!= == === => -> <= >= && ||' --output-format=json
hb-shape "$PRAGMATA_DIR/PragmataPro_Mono_R_liga_0903.ttf" \
	'!= == === => -> <= >= && ||' --features=calt=0 --output-format=json
hb-shape "$PRAGMATA_DIR/PragmataPro_Mono_R_0903.ttf" \
	'!= == === => -> <= >= && ||' --output-format=json
```

The Liga default selects operator drawings that differ from the `calt=0`
result. The non-Liga default keeps the separate operator glyphs. All three
results have a total horizontal advance of 27,648 font units, or 27 cells
of 1,024 units. The Liga on/off results retain clusters 0 through 26.

For optional badges, compare the same label text with no override and with
`--features=ss15=1,ss18=1`. For Git joins, compare `ss13=0` and `ss13=1`.
The committed PNG shows these differences. Its word panel deliberately uses
`ss12=1` to show why that setting remains optional.

## Render a sample without installing the font

```sh
hb-view "$PRAGMATA_DIR/PragmataPro_Mono_R_liga_0903.ttf" \
	'!= === -> [TODO]' --font-size=36 --output-file=/tmp/pragmatapro.png
```

The committed contact sheet uses `hb-view` for its font panels. It uses the
Regular Mono Liga TTF except for the panel explicitly marked PragmataPro Liga.
Panels use `calt=0`, font defaults, `ss15=1,ss18=1`, `ss12=1`, or `ss13=1`
as labeled. It embeds rasterized samples, not font software.

## Verify the examples

Ghostty's installed `+validate-config --config-file=PATH` command checked
temporary files with the documented family and feature settings. This checks
syntax. It does not prove a particular application rendered every glyph.

`merman-cli lint` checked both diagrams in the explanation. TOML parsing checked
the Rex appearance example inside `[bootstrap.macos.defaults]`. The static
specimen was checked for control characters and aligned box widths.

The Obsidian CSS selectors match the installed 1.14.5 stylesheet. No real
vault was changed, so theme-specific overrides and actual-vault rendering
remain unverified. No IDEA terminal ligature result is claimed.

## Local observations

Rex's Terminal settings displayed `PragmataPro Mono Liga`, Regular, 16 pt,
and Ligatures on. A subsequent read of `com.superlogical.rex.plist` showed
`Workspace.terminalFontName` as that family string and
`Workspace.terminalFontPointSize` as the real number `16.0`.
`Workspace.terminalAllowsLigatures` was absent, so the UI was the evidence
for its current default. Internal preference names came from the installed app.

Ghostty's font-list command returned no entries in the automation context,
even outside the initial restriction. That result does not establish whether
a font is installed. The live Rex UI and direct font-file rendering supplied
the useful observations instead.

The license discussion reads the bundle's `COPYRIGHT+EULA.txt`, v4.0 dated
2025-04. The separate [public terms](https://fsd.it/shop/terms/) have a newer
version. This report does not infer purchase entitlements from either the
folder contents or the newer public page.
