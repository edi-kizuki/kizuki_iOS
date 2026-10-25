---
title: Illustration asset manifest (vector + raster exports)
created: 2026-10-25
tags: [project/kizuki, design, illustrations, assets]
status: exported
---

# Illustration asset manifest

Related: [[2026-10-25-figma-full-walkthrough]], [[2026-10-24-architecture-round-1-interview]], [[playbook]]

Exported 2026-10-25 via Figma MCP `download_assets` (Full seat, read-only). Each SVG is the **vector layer export** (`svgAssets`), not the frame render. That means: transparent background, exact node size, no frame fill. The tool's whole-node `export` SVG adds a `#F5F5F5` background rect and was not used.

Sources:

- Illustrations file `dPirB4bC1bB7KcxaacOVHG` (Kizuki illustrations (Copy)), page `0:1`.
- App file `nPqXTMCtd3OVZTSU7Y2uN3` (Kizuki App (Copy)), pages "Drawings" `1434:6420` and "Components" `221:2524`.

## Vector (SVG) in this folder

Sizes are the SVG `width × height` in px (1:1 with the Figma node). All are true vectors (paths only, no embedded rasters).

| File | Content | Source file | Node id | Format | Size (px) | Vector | Fill |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `illustration-1.svg` | Painter, brushes in hair, palette (frame "1") | Illustrations | `1:14` | SVG | 209.969 × 224.037 | yes | black |
| `illustration-2.svg` | Snake-hair musician with ukulele (frame "2") | Illustrations | `1:28` | SVG | 179.272 × 214.053 | yes | black |
| `illustration-3.svg` | Photographer with camera (frame "3") | Illustrations | `1:90` | SVG | 132 × 202 | yes | black |
| `illustration-4.svg` | Winged figure, spiky hair (frame "4") | Illustrations | `1:2` | SVG | 253.292 × 244.201 | yes | black |
| `illustration-5.svg` | Horned punk, cow-print top (frame "5") | Illustrations | `1:55` | SVG | 117.231 × 200.676 | yes | black |
| `illustration-6.svg` | Antlers with hanging crystals (frame "6") | Illustrations | `1:65` | SVG | 182.119 × 223.952 | yes | black |
| `illustration-7.svg` | Horned figure, raised hand (frame "7") | Illustrations | `1:43` | SVG | 187.634 × 245.180 | yes | black |
| `illustration-8.svg` | Antenna alien with star pendant (frame "8") | Illustrations | `1:77` | SVG | 134.921 × 229.766 | yes | black |
| `illustration-9.svg` | Three dancing figures (stick figure, fox, jumper). Used orbiting Suki on the Get Started screen. | App, Drawings | `1435:14445` ("Group 48096407") | SVG | 650.011 × 366.625 | yes | `#1A1A1A` |
| `illustration-10.svg` | Orange topographic swirl pattern (splash/background shapes) | App, Drawings | `1435:14439` ("Vector") | SVG | 2794.1 × 1472.63 | yes | `#FF4B1E` |
| `illustration-11.svg` | Mascot sheet "Layer_1": three-eyed cat heads, fox, eye creature, star creature and more (34 paths) | App, Drawings | `1434:4207` | SVG | 2542.06 × 733.16 | yes | black (+1 white clip rect) |
| `illustration-12.svg` | Suki mascot (centre creature on the Get Started screen; drawn blue there, orange in this source) | App, Components | `614:9214` ("Suki") | SVG | 48.9654 × 70 | yes | `#E95833` |

Notes:

- The 8 character frames are black line art on transparent. The in-app screens show light-on-dark versions, so recolour in code (template rendering or per-asset tint).
- The Drawings page repeats the 8 characters (`1602:4569` "1", `1602:4583` "2", `1602:4645` "3", `1602:4557` "4", `1602:4610` "5", `1602:4620` "6", `1602:4598` "7", `1602:4632` "8") and adds copies "12" `1609:430` and "14" `1609:452`. Verified by byte diff: `1602:4569` equals illustration-1, `1602:4598` equals illustration-7, `1609:430` equals illustration-7 and `1609:452` equals illustration-6 (only the SVG `id` differs). **No new characters on the Drawings page**; the frames are duplicates.
- Client brief on the Drawings page (`1574:4532`) asked for 4 discipline characters plus 3 neutral ones. The file holds 8 finished drawings. Which maps to which discipline is **not labelled** in Figma. Needs a human decision.
- `illustration-9`, `-10`, `-11`, `-12` are not named "illustration" in Figma. They are numbered here only for file ordering.

## Raster and non-vector in `../export/`

| File | Content | Source file | Node id | Format | Size (px) | Vector | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `icon-2-1.png` | "icon 2 1": sheet of 10 black blob/burst shapes (starbursts, clouds, splats) | Illustrations | `8:2849` | PNG @1x | 2555 × 1042 | no | Opaque `#F5F5F5` frame background baked in. Not an app icon despite the name. |
| `icon-2-1-source-4000x1632.png` | Raw image fill of the same node (highest-resolution source) | Illustrations | `8:2849` | PNG | 4000 × 1632 | no | RGBA. Use this one for slicing individual shapes. |
| `icon-2-1-svg-wrapper-with-embedded-raster.svg` | SVG export of `8:2849` | Illustrations | `8:2849` | SVG | 2555 × 1042 | **no** (embeds the raster as an `<image>` pattern, 423 KB) | Not a real vector. Kept only for completeness. Needs retracing to get vector shapes. |
| `reference-only-IMG_6719-welcome-group-1416x736.png` | Four portrait characters shown on the Welcome screen | App, Drawings | `1574:4533` ("IMG_6719 2") | PNG @4x | 1416 × 736 | no | **Do not ship.** The layer name and raw fills show it is a crop of an iPhone screenshot of another app (the moodboard lists "IMG_6706-IMG_6719" as Pure app inspiration screenshots). Opaque grey background. The Welcome screen uses it as a placeholder. |

## Limits

- The frames "1"-"8" are raw drawings at about 120-250 px, so the SVG paths are the only high-fidelity form. Do not rasterise below 2x for display.
- `get_screenshot` and `download_assets` PNG exports cap at the node's natural size times the scale (max 4); a 2048 px transparent PNG of the small character frames was not needed because SVG is available.
- No character PNG exports were created. SVG covers them.
- Frames named "FINAL" (`1602:4660`) and the "Final version" marketing page (`1435:14032`) were not exported (marketing site layout, not asset art).
