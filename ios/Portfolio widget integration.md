# Portfolio widget integration

Related: [[Models]], [[ProfileView]], [[AppStore]], [[StockPhotoCredits]], [[2026-10-27-roles-persistence-staging]].

## Implemented boundary

`ProfileLink` remains the persisted portfolio input, one link per provider. Profile editing validates new or changed HTTPS URLs against provider hosts. Existing fictional demo links remain visible as disconnected placeholders and can be cleared. Save is atomic through the profile repository. Portfolio links do not feed recommendation scoring.

The user-facing section is **Portfolio**, not Portfolio widgets. This supersedes the earlier **Your links** editor heading and **Work** profile heading. Each provider has a branded card and a Connect/Edit action. Connect currently opens an honest link-only setup sheet, not an OAuth authorization page. The sheet explicitly says account sign-in is unavailable. New links are validated and applied to the profile draft with Use link; Save persists that draft. Cancel discards only the sheet's changes. Remove link explicitly clears a configured link. Invalid or unfinished sheet input never disables the whole profile's Save action.

New links accept leading/trailing whitespace, a missing HTTPS scheme, and uppercase HTTPS/host names. Both the editor and store use the same normalization before origin validation. Explicit HTTP, credentials, ports, embedded whitespace, backslashes and spoofed provider hosts remain rejected. No redirects or metadata are fetched.

Configured providers have an optional **Show on profile** toggle, with a provider-specific accessibility label. Turning a widget off retains its URL; turning it back on restores it. Visibility is persisted per link. Older saved links without a visibility field remain visible. Disabled widgets do not load third-party content. These controls currently use the local profile repository; live syncing and playback remain pending.

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

### Account authorization blockers, October 28, 2026

There are no provider app IDs, registered callback configuration or provider token services in this repository. Do not substitute a provider home/login URL for an authorization flow, use Supabase credentials as provider credentials, or mark a manually saved URL as an authenticated account. The current UI reports links as added, hidden or shown, never authenticated.

Before enabling external authorization, register Kizuki with each supported provider, implement an authenticated server-side account-linking service, and add an `ASWebAuthenticationSession` client. Bind state and PKCE to the initiating user/session, strictly validate the callback, handle denial/cancellation/expiry, retrieve the provider's canonical public profile, and persist only after confirmation. Provider secrets and refresh tokens belong on the backend. Hiding a widget must stay separate from disconnecting/revoking an account. Portfolio authorization must not grant matching consent.

Provider documentation inspected on October 28:
- YouTube: Google OAuth registration and an iOS client are required. Request only the read scopes needed to resolve the channel. https://developers.google.com/youtube/v3/guides/auth/installed-apps
- SoundCloud: registered application, OAuth 2.1 and required PKCE; token exchange requires the application secret. https://developers.soundcloud.com/docs/api/guide
- TikTok: register an app and configure Login Kit, its client key and callback before launching authorization. https://developers.tiktok.com/doc/login-kit-ios-quickstart
- Bandcamp: API access is granted by contacting Bandcamp; the documented API targets account/sales/merchandise use. Do not assume general consumer portfolio authorization is approved. https://bandcamp.com/developer
- Instagram: verify the current supported account types, scopes and review requirements before selecting an authorization product. Consumer-account support is not verified in this pass.
- Letterboxd: the API beta page returned HTTP 403 during this pass. API eligibility and general account authorization remain unverified; keep manual links until approved. https://letterboxd.com/api-beta/

The Connect sheet is a fallback, not completed OAuth integration. No provider credentials were requested or added during this pass.

Brand assets: see [[Provider icon credits]].

October 28 verification: 83 unit tests passed, including all provider logo resources, scheme normalization, spoofed URLs, hidden-link state and save atomicity. Both editor UI tests passed: adding scheme-less URLs, saving/reopening, hiding without deleting, and cancelling invalid input without blocking profile Save. Ten release-configuration tests and the Staging build/artifact check passed. External authorization and live profile syncing remain unverified and unimplemented.

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
