---
title: Kizuki icon and logo sources
created: 2026-10-25
tags: [project/kizuki, design, icons]
---

# Kizuki icon and logo sources

Related: [[2026-10-25-design-tokens]], [[2026-10-25-icon-sheet-reference]], [[2026-10-25-prototype-report]], [[2026-10-24-architecture-round-1-interview]] (decisions 56 and 57)

## Where each asset came from

### Current logo — October 28, 2026

Related: [[Header appearance experiment]]. The user reversed the `concept_8` (`570:2`) experiment. The original `concept_8.6` wordmark, K mark and app-icon artwork are restored. Tab icons are unchanged.

- Feed uses its original `1312:8143` artwork, with the blue body changed to palette yellow `#EBAF41`; charcoal eye details are preserved. The splash crest is restored.
- `figma/app-icon-artwork-614-319.svg` supplies the original app-icon K. The tile is opaque and square; iOS supplies the mask. Light: charcoal on cream. Dark: palette orange `#E95833` on charcoal. Tinted: white on black for system tinting.
- `python3 docs/design/icons/tools/build-brand.py` regenerates the three 1024-pixel app-icon PNGs only. Requires `rsvg-convert`. It does not overwrite the restored logo assets.
- Feed DMs use `tabler:message-circle-filled`, exported from Kizuki App (Copy), file `nPqXTMCtd3OVZTSU7Y2uN3`, node `1312:10726`. Bundled as `IconMessages.svg` and template-tinted palette orange `#E95833`. The 44-point target and Messages accessibility label are unchanged.
- Rechecked Figma variables: `1312:8064` confirms Kizuki Blue `#3F7BE2`; `1312:9852` confirms Kizuki Orange `#E95833`. The banner uses Blue, not Baby Blue icons `#B7C4DF`.

The following inventory describes the original local exports; some historical intermediate files remain locally ignored. The app-icon source above and bundled runtime assets are tracked.

| Folder | What | Source | Vector or raster |
| --- | --- | --- | --- |
| `figma/` | Raw Figma exports (logos, K marks, app icon artwork) | Figma "Playground (Copy)", fileKey `3po5ynomzdPNe2mcO7IKRw`, page "Kizuki \| Moodboard", frame `concept_8.6` (`614:260`) | SVG (vector). One PNG preview at 4x |
| `brand/` | Historical clean wordmark and K mark (background rectangles removed, eye cut-outs kept) | Prepared from `figma/`; current runtime copies live in `KizukiIcons.xcassets` | SVG |
| `app-icon/` | App icon, light / dark / tinted, SVG plus 1024 PNG with no alpha | Built from the Figma app-icon artwork `614:319` | SVG source, PNG render |
| `sheet-traced/` | The 26 tab icons from the reference sheet: the five current ones and 21 alternates | **Traced from `../2026-10-25-icon-sheet-reference.jpg`** with potrace (`tools/crop-sheet.swift`, `tools/build-tab-icons.py`) | SVG (vector, but traced from a raster) |

## Important: the tab icons are not in Figma frame concept_8.6

Frame `614:260` (and the rest of the "Kizuki | Moodboard" page and the other two pages) holds the brand work: the wordmark, the K mascot, the mascot pair with the star, the app icon on a cream tile, a dark and an orange K, the splash mock screens and the colour strip. It does **not** contain the tab-bar icon set from the reference sheet (polaroid with star, magnifier with star, eye disc, folder with star, bust with starburst and the rest). I searched all three pages by layer name and by thumbnail; there are no matching vector nodes.

So the tab icons were traced from the reference JPG (1280 x 896, each icon about 100 px). They are clean at tab-bar size (about 28 pt) but they are a trace, not the designer's original paths. **Replace them with the Figma originals when the designer exports them** (same file names in `sheet-traced/`, then re-copy the five used ones into the asset catalog). The sheet's colour (blue, red) is dropped: icons ship as one-colour template images so the tab bar can tint them. Inner details (stars, eye pupils) are cut-outs.

## Figma node ids (all in file `3po5ynomzdPNe2mcO7IKRw`)

| File | Node | What |
| --- | --- | --- |
| `figma/wordmark-614-262.svg` | `614:262` | "kizuki" wordmark (Layer 1 = "izuki" letters `614:263`, Layer 2 = the K glyph with eyes `614:269`). The export includes the cream frame rectangle |
| `figma/wordmark-letters-izuki-614-263.svg` | `614:263` | Letters only |
| `figma/wordmark-k-glyph-614-269.svg` | `614:269` | K glyph of the wordmark |
| `figma/k-mark-eyes-614-372.svg` | `614:372` | K mascot with eyes, brown `#733635` on cream tile |
| `figma/k-mark-eyes-alt-614-366.svg` | `614:366` | K mascot with eyes, orange `#FF6139` on `#1A1A1A` |
| `figma/k-mark-silhouette-614-337.svg` | `614:337` | K silhouette inside the app-icon frame |
| `figma/app-icon-artwork-614-319.svg` and `@4x.png` | `614:319` ("icon - edid this") | App icon: cream `#F2EEE7` tile, `#1A1A1A` K with eye cut-outs. The Figma tile has rounded corners (rx 80 of 293); iOS applies its own mask, so the shipped icon is the same artwork on a full-bleed square |
| `figma/mascot-pair-star-614-271.svg` | `614:271` | Two Ks facing each other under an orange star (illustration, not used in the app yet) |
| `figma/concept_8.6-614-260-preview.png` | `614:260` | Screenshot of the whole frame |

The `figma/` exports still contain the Figma wrapper rectangles (white canvas, grey `#F5F5F5`). The `brand/` and `app-icon/` files are the cleaned versions.

## What the app uses

Asset catalog: `ios/Packages/KizukiKit/Sources/KizukiDesignSystem/Resources/KizukiIcons.xcassets` (SVG, Preserves Vector Data, template rendering). Swift access: `KizukiIcon` in `KizukiIcons.swift`.

| Asset | Used for | Source |
| --- | --- | --- |
| `TabHome` | Home tab | `sheet-traced/alt-home-polaroid-star.svg` |
| `TabSearch` | Search tab | `sheet-traced/alt-search-magnifier-star.svg` |
| `TabSuki` | Suki tab | `sheet-traced/current-suki-eye-disc.svg` |
| `TabMyProjects` | My Projects tab | `sheet-traced/alt-projects-folder-star.svg` |
| `TabProfile` | Profile tab | `sheet-traced/alt-profile-bust-starburst.svg` |
| `KizukiWordmark` | Splash screen | `brand/kizuki-wordmark.svg` (Figma `614:262`) |
| `KizukiKMark` | Sign-in screen | `brand/kizuki-k-mark-ink.svg` (Figma `614:372`) |

App icon: `ios/App/Assets.xcassets/AppIcon.appiconset` (one 1024 icon plus dark and tinted variants; `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`).

## Swapping a tab icon

1. Pick an alternate from `sheet-traced/` (see the contact sheet `sheet-traced/_contact-sheet.png`).
2. Edit `chosen` in `tools/build-tab-icons.py` (for example `'TabHome': 'i10'`), run it, rebuild.
   The tool scripts have absolute paths and read `/tmp/kz_trace/*.svg`, the potrace output from `crop-sheet.swift`. Simplest manual route: copy the alternate's SVG over `TabHome.imageset/TabHome.svg` and change `fill="#F2EEE7"` to `#000000`.
