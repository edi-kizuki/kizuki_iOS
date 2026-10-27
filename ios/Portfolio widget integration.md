# Portfolio widget integration

Related: [[Models]], [[ProfileView]], [[AppStore]], [[StockPhotoCredits]], [[2026-10-27-roles-persistence-staging]].

## Implemented boundary

`ProfileLink` remains the persisted portfolio input, one link per provider. Profile editing validates new or changed HTTPS URLs against provider hosts. Existing fictional demo links remain visible as disconnected placeholders and can be cleared. Save is atomic through the profile repository. Portfolio links do not feed recommendation scoring.

Each provider has an optional Show widget toggle. New, unconfigured widgets start off. Turning a configured widget off hides its card while retaining its URL; turning it back on restores it. Visibility is persisted per link. Older saved links without a visibility field remain visible. Enabled widgets require a URL. Disabled widgets do not load third-party content. These controls currently use the local profile repository; live syncing and playback remain pending.

The live public profile projection must omit disabled links rather than rely only on client rendering. Keep saved hidden URLs in the owner's private profile data.

Widget-toggle verification: 80 unit tests, the end-to-end editor toggle/save/reopen test, and 10 release-configuration checks passed. The Staging build and artifact inspection passed. Tests cover all three requested providers, hidden-link cold restoration, legacy decoding, and TikTok origin validation.

`PortfolioWidgetDescriptor` resolves typed states without network access or arbitrary HTML: invalid, link-only, embed-available, metadata-required. It exposes a validated external destination and, where supported, a canonical player URL. Rendering currently uses external links only. No cookies, autoplay, remote metadata, or third-party scripts load merely because a profile is visible.

| Provider | Prepared behavior | Work before in-app playback |
| --- | --- | --- |
| YouTube | Parse watch, short-link, shorts and embed IDs; build youtube-nocookie player URLs | Tap-to-load consent; restricted WebKit player; test unavailable/private/restricted videos and accessible playback |
| SoundCloud | Canonical player URL for track and playlist paths, autoplay false | Tap-to-load consent; widget lifecycle/events; offline/removed-track handling |
| Bandcamp | Valid album/track link, metadata-required state | Resolve numeric album/track ID using an approved provider flow; never guess IDs or inject scraped HTML |
| Instagram | Validated external link | Keep external until a supported, review-safe embed/auth path is chosen |
| Letterboxd | Validated external link | Optional user-authorized RSS import later; preview before save; no automatic matching use |
| TikTok | Optional profile/video/share link on explicitly allowed TikTok HTTPS hosts | External link only; approved embed flow and consent-gated player remain pending |

## Next implementation contract

Build the shared player in a non-Debug module, not inside the fixture-only profile view. Accept only a validated descriptor. Create the WebKit view only after explicit playback consent. Use a nonpersistent website data store, disable autoplay, constrain navigation and script capabilities to provider requirements, and route external navigation through explicit user action. Never accept server-supplied HTML as trusted UI. Consent to portfolio playback must not enable matching consent.

Metadata adapters should return typed IDs, titles, thumbnail URLs and availability, never HTML. Validate redirects and final origins, bound response size/time, cache with expiry, and support cancellation on reuse. Use backend-held credentials only where a provider requires them. Do not put provider secrets in iOS. Inspect current provider terms before implementing any adapter.

Keep local fixture links separate from real authenticated profile writes. The live own-profile repository and Supabase schema deployment remain unfinished; local persistence does not establish live integration. Surface loading, offline, denied consent, unavailable media and retry states explicitly.

## Validation checklist

- Unit tests: accepted URL shapes, host spoofing, credentials, ports, invalid schemes, Bandcamp IDs not invented, duplicate providers, persistence failures.
- UI tests: edit/remove links, keyboard-safe Save, external destination accessibility, no pretend playback.
- Integration tests still needed: provider responses, cookies/network before consent, redirects, background playback cancellation, content restrictions and real authenticated profile reads/writes.

References: https://developers.google.com/youtube/player_parameters ; https://developers.soundcloud.com/docs/api/html5-widget .

## October 27 verification

77 local unit tests, 17 prototype UI tests and 10 release-configuration checks passed. The Staging build and release artifact inspection passed; the negative control still rejects Debug fixture code. On iPhone 17 Pro Latest, verified Painter in Visual arts, bundled discovery photos, and editing/saving a valid YouTube link with the keyboard open. The saved link renders an explicit external action, not a pretend player. No third-party page was opened in this verification. Live Supabase deployment remains pending.
