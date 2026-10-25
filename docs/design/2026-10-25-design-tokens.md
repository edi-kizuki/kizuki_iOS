---
title: Kizuki design tokens (Figma-returned values only)
created: 2026-10-25
tags: [project/kizuki, design, figma, tokens]
status: partial-verified
source-file: nPqXTMCtd3OVZTSU7Y2uN3 (Kizuki App (Copy))
---

# Kizuki design tokens

Related: [[2026-10-25-figma-full-walkthrough]], [[2026-10-24-architecture-round-1-interview]], [[playbook]]

Rules for this file:

- Every value below was returned by `get_variable_defs` or `get_design_context` on the node ids shown (2026-10-25, Full seat). Nothing is inferred.
- `get_design_context` returns React + Tailwind. Values are copied from its classes (`text-[16px]`, `rounded-[20px]`). `leading-none` is Tailwind for line-height 1.0 (100%). Treat that as the tool's translation, not a Figma text-style value.
- Where Figma returned nothing, the cell says **gap**.
- Screenshots: [[2026-10-25-figma-full-walkthrough]] section "Visual pass (2026-10-25)".

## Variable collections

Figma returned **colour variables only** for the app frames. No type, spacing or radius variables exist on any queried node. The only typography variables (`SF Pro` styles) and `Helper/Label/*` (`SF Mono`) styles come from the stock iOS kit and the Toggle spec sheet, not from Kizuki screens.

## Colours (variables)

| Variable | Hex | Returned on node ids |
| --- | --- | --- |
| Charcoal | `#1A1A1A` | `1312:8064`, `1312:9852`, `1312:10374`, `1312:8654`, `1480:4256`, `1290:7947`, `1485:5384`, `1312:9342`, `1312:12209`, `1312:12351`, `1361:12184`, `1361:12567`, `1418:3514`, `1526:4399`, `1312:11087`, `1478:3770`, `1312:10492`, `1480:4806`, `1468:5306` |
| Cream | `#F2EEE7` | same set (all frames except `1312:11087`, `1312:11134`) |
| Kizuki Orange | `#E95833` | `1312:9852`, `1312:10374`, `1312:8654`, `1480:4256`, `1290:7947`, `1485:5384`, `1361:12184`, `1361:12567`, `1418:3514`, `1312:11134`, `1526:4399`, `1312:10492`, `1480:4806` |
| Kizuki Blue | `#3F7BE2` | `1312:8064`, `1312:9852`, `1290:7947`, `1485:5384`, `1312:9342`, `1361:12184`, `1418:3514`, `1478:3770`, `1312:10492`, `1480:4806`, `1468:5306` |
| Kizuki Yellow | `#EBAF41` | `1290:7947`, `1485:5384`, `1361:12567`, `1418:3514`, `1480:4806` |
| Kizuki Baby Blue Backgrounds | `#C6CEDF` | `1312:8064`, `1312:9852`, `1361:12184`, `1418:3514`; also fill of feed content frame `1468:4888` |
| Kizuki Baby Blue icons | `#B7C4DF` | most frames; also tab bar page-fill rect `I1468:4979;1357:9101` |
| Grey | `#333333` | `1312:8064`, `1312:9852`, `1312:12209`, `1312:12351`, `1480:4806` |
| Kizuki Grey | `#242424` | `1312:9852`, `1312:12351`, `1418:3514` |
| Kizuki Salmon | `#FAC5B8` | `1312:9342` (search filter chips) |
| Ink | `#371F1D` | `1526:4399` (Create Account screen background, dark brown) |

Stock iOS kit variables (returned on `1290:7947` only; from the Apple UI kit, not Kizuki brand): `ui/accent` `#007bfe`, `system/grey` `#8e8e93`, `system/black` `#000000`, `label/primary` `#000000`, `bg/primary-base` `#ffffff`, `screen/width` 430, `screen/height` 932, `homebar/width` 154.

Toggle spec sheet `346:3696` styles: `Default/SystemGreen/Light` `#34C759`, `Default/SystemGreen/Dark` `#30D158`, `Fill Color/Light/Secondary` and `Fill Color/Dark/Secondary` `#787880`, `System Background/Light/Primary` `#FFFFFF`.

### Literal colours seen in `get_design_context` (not variables)

| Use | Value | Node |
| --- | --- | --- |
| Input placeholder text | `rgba(255,255,255,0.6)` | `1480:4262` / text `1480:4267` |
| Input bottom border | `rgba(255,255,255,0.2)`, 0.6 px | `1480:4262` |
| Helper text | `rgba(255,255,255,0.5)` | `1480:4277` |
| Section heading on dark | `rgba(255,255,255,0.8)` | `1480:4282` |
| Button fill (Next, disabled look) | `#e95833`, opacity 0.5 | `1480:4278` |
| Button border | white, 1 px | `1480:4278` |
| Button shadow | `drop-shadow 4px 4px 0 rgba(255,255,255,0.8)` | `1480:4278` |
| Card caption bar | `#333` | `1468:5068`, `1312:8123` |
| Search field fill | `#f2eee7`, placeholder `rgba(26,26,26,0.5)` | `1312:9409` |
| Chip active fill and border | `#3f7be2` | `1468:5152` |
| Chip inactive fill and border | `#1a1a1a`, text `#c6cedf` | `1468:5154` |
| Chat bubble (sent) fill | `#f2eee7`, text `#1a1a1a`, mention `#3f7be2` | `1312:10376` |
| Chat composer border | `#f2eee7`, 0.6 px | `1312:10382` |
| Project info panel | fill `#f2eee7`, border `#3f7be2` 1 px | `1485:5404` |
| Yellow CTA | fill and border `#ebaf41`, text `#1a1a1a` | `1488:6508` |

Observed (screenshots, not Figma-returned): the Suki tab eye colour varies frame by frame (blue on Home, Search grid, scrolled project detail and request form; orange on Suki landing, chat, settings, profile, create form; yellow on `1449:4146`). It does not mark the active tab. See the walkthrough visual pass.

## Typography (from `get_design_context`)

Families in use: **Londrina Solid** (display), **DM Sans** (UI/body), **DM Mono** (labels/buttons/captions), **Poppins** (form copy, bio, helper). Sizes in px as returned; Figma px map 1:1 to pt on the 393 pt frame.

| Role | Family / weight | Size | Line height | Tracking | Colour | Node |
| --- | --- | --- | --- | --- | --- | --- |
| Screen title (account creation) | Londrina Solid Regular, uppercase | 32 | normal | **gap** | Cream | `1480:4260` |
| Welcome title | Londrina Solid Regular, uppercase | 36 | normal | **gap** | Cream | `1480:4261` |
| Section heading (small) | Londrina Solid Regular | 20 | 22 | **gap** | white 0.8 | `1480:4282` |
| Card-group heading ("Projects", "Recomended projects") | Londrina Solid Regular | 24 | 1.0 (leading-none) | **gap** | Cream | `1468:5092`, `1312:8066` |
| Primary button label | Londrina Solid **Black**, uppercase | 16 | 1.0 | 1.12 px | Cream | `1480:4279` |
| Input text / placeholder | Poppins Regular | 15 | 1.0 | **gap** | white 0.6 | `1480:4267` |
| Helper text | Poppins Regular | 12 | 22 | **gap** | white 0.5 | `1480:4277` |
| Card title | DM Sans Medium (`opsz 14`) | 20 | 1.0 | **gap** | white | `1468:5069` |
| Card subtitle (city) | DM Sans Medium | 16 | 1.0 | **gap** | white | `1468:5070` |
| People tile name / role | DM Sans Medium | 12 / 11 | 1.0 | **gap** | white | `1312:8125`, `1312:8126` |
| Filter chip label | DM Sans Medium | 12 | 1.0 | **gap** | `#c6cedf` (inactive), `#1a1a1a` (active) | `1468:5155`, `1468:5153` |
| Feed sort control labels | DM Sans Bold / Medium | 12 | 1.0 | **gap** | blue/cream (rendered transparent in the instance) | `1468:4968` |
| Settings page title | DM Sans SemiBold | 30 | 1.0 | **gap** | Cream | `1312:8655` |
| Settings row label | DM Sans SemiBold | 13 | 1.0 | **gap** | Cream | `1312:8689` |
| Search field text | DM Sans Regular (query) / SemiBold ("x") | 14 | 1.0 | **gap** | `rgba(26,26,26,0.5)` / `#1a1a1a` | `1312:9413`, `1312:9414` |
| Chat message | DM Sans Regular; mention DM Sans Medium | 15 | 1.0 | **gap** | Charcoal; mention Blue | `1312:10377` |
| Chat composer text | DM Sans Regular | 16 | 1.0 | **gap** | Cream | `1312:10385` |
| Chat composer "+" | DM Sans Medium | 26 | 1.0 | **gap** | Cream | `1312:10384` |
| Project title | **Poppins Bold** | 16 | 1.04 | -0.48 px | Charcoal | `1485:5427` |
| Project description | DM Mono Medium, justified | 12 | 1.0 | -0.48 px | Charcoal | `1485:5407` |
| Project field labels (Category, Roles) | DM Mono Medium | 14 | 1.0 | -0.42 px | Charcoal | `1485:5411` |
| Project tag chip text | DM Mono Medium | 12 | 1.0 | -0.36 px | Charcoal | `1485:5416` |
| Yellow CTA label | DM Mono Medium | 16 | 1.0 | -0.48 px | Charcoal | `1488:6509` |
| Toggle spec sheet labels (stock) | SF Mono Semibold 18 / Regular 14, line 24, tracking 0.38 | | | | | `346:3696` |

Gaps: mobile Dynamic Type mapping, bold/italic variants of Londrina (Black appears only on buttons), minimum text sizes for caption text (the smallest returned is 11).

Note: the moodboard poster scale ("96 px", "32 px") from the earlier pass is not an app type scale and should not be used (see walkthrough).

## Radii

| Element | Radius | Node |
| --- | --- | --- |
| Primary button (Next) | 1 | `1480:4278` |
| Input | 1 (bottom border only) | `1480:4262` |
| Filter chip (feed) | 15 (22 px high) | `1468:5152` |
| Nested chip container | 6 | `1468:5157` |
| Nav bar bottom corners | 20 | `1468:4968` |
| Feed section card (Rectangle 186884) | 20 | `1312:8065` |
| Search field | 20 | `1312:9409` |
| Project tag chip | 18 | `1485:5415` |
| Yellow CTA pill | 27 | `1488:6508` |
| Chat bubble | TL/TR/BR 30, BL 3 (sent bubble, rotated frame) | `1312:10376` |
| Chat composer | 30 | `1312:10382` |
| Project info panel | none (square, 1 px blue border) | `1485:5404` |

Gaps: card image radius (images are fills), avatar radius (ellipse), hand-drawn rough borders (vector/image assets, no radius value).

## Spacing and layout (from `get_design_context` / `get_metadata`)

| Element | Value | Node |
| --- | --- | --- |
| Frame | 393 × 852 (long frames up to 2206) | all |
| Nav bar | 393 × 116, top padding 70, item gap 67, icon gap 20 | `1468:4968` |
| Status bar | 393 × 54 | `1468:4978` |
| Tab bar | 393 × 103; icon row 80 high at y 9; gap 50; padding-x 2 | `1468:4979` |
| Tab icons | 24 × 24 (eye-circle 33.36 × 33.36) | `1468:4979` children |
| Segmented control | gap 5, chip height 22, padding 10, border 2 | `1468:5151` |
| Feed project card | 365 × 354; image 365 × 289; caption 365 × 65; icon row gap 20.36, padding 20.36 | `1468:5059`, `1468:5068` |
| Recommended-card carousel item | 318 × 348 (card at x 10) | `1312:8069` |
| People tile | 100 × 90, gap 16 | `1312:8123` |
| Settings row | 33 high, icon 24, label inset 34, rows 53 apart | `1312:8656` etc. |
| Input | 320 × 48, padding-x 12, padding-y 10, gap 12 | `1480:4262` |
| Primary button | 249 × 48, padding 20 × 16 | `1480:4278` |
| Search field | 354 × 36, padding 10, gap 10 | `1312:9409` |
| Chat composer | 373 × 50, padding 14 | `1312:10382` |
| Project info panel | 381 × 254 | `1485:5404` |
| Yellow CTA | 361 × 36, padding 10 | `1488:6508` |

Gaps: a spacing scale. The values are pixel-ad-hoc, not a 4/8 grid (20.36, 10.18, 65.15 appear because the cards were scaled).

## Shadows and effects

| Element | Value | Node |
| --- | --- | --- |
| Primary button | `4px 4px 0 rgba(255,255,255,0.8)` hard offset, no blur | `1480:4278` |
| Others | **gap** (tab bar page-fill rect and card glows are image/vector assets) |

## Components read via `get_design_context`

| Component | Node | Result |
| --- | --- | --- |
| Project card | `1468:5059` + caption `1468:5068` | Image fill + 3 action icons (`solar:heart-bold`, `lets-icons:view`, `uil:comments`, 24 px) over image; caption bar `#333` with DM Sans Medium 20/16. Share and save icons exist in other states. |
| Primary button | `1480:4278` | See typography and shadow rows. Disabled look = opacity 0.5. Enabled look in `1312:11996` screenshot is full opacity. |
| Chip (segmented) | `1468:5151` | 6 chips: All, Music, Technology, Photography, Modeling, Developers. |
| Tab bar | `1468:4979` | 5 icon-only items; `bg #1a1a1a`; no text labels. |
| Input | `1480:4262` | Underline field, no box. |
| Nav bar | `1468:4968` | `bg #1a1a1a`, bottom radius 20; contains hidden Logo (opacity 0), "For you / Following" controls (text colours transparent in the instance), settings and chat icons. |
| Toggle | `346:3696` | iOS-stock; images per state (dark/light × active). |
| Tag chip (project) | `1485:5415` | 1 px charcoal border, radius 18, DM Mono Medium 12. |
| Search field | `1312:9409` | Cream pill. |
| Chat bubble + composer | `1312:10376`, `1312:10382` | See rows above. |

## Corrections to the earlier (layer-only) token table

- `Ink` is `#371F1D` (dark brown), not `#FF6139`. The earlier "Ink/Orange Peel" naming conflict is resolved for the app: **Kizuki Orange `#E95833` is the in-app accent**; `#FF6139` (moodboard text) did not appear in any app variable.
- `Kizuki Blue #3F7BE2`, `Kizuki Yellow #EBAF41`, `Cream`, `Charcoal` match the moodboard. `Dusty Blue #A1CACC` and the nine "Secondary" colours did **not** appear as variables on any queried app frame.
- New: `Kizuki Baby Blue Backgrounds #C6CEDF`, `Baby Blue icons #B7C4DF`, `Grey #333333`, `Kizuki Grey #242424`, `Kizuki Salmon #FAC5B8`.
- Fonts confirmed in app nodes: Londrina Solid, DM Sans, DM Mono, Poppins. The moodboard note "small text dm mono, handle/bio/location Poppins" matches (project descriptions use DM Mono; helper/input use Poppins). DM Sans carries UI chrome (cards, chips, chat, settings, search), which the moodboard did not state.
