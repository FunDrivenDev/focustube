# Research

What YouTube lets focustube do, and what that means for the product. Written on 2026-09-27; YouTube changes often, so each claim carries its source and date in the two reports.

- [What the official YouTube and Google APIs allow](official-youtube-api.md): the Data API, its quota, RSS feeds, the embedded player, Premium, sign-in, and the API policies.
- [Community YouTube data tools and account risk](community-tools-and-account-risk.md): yt-dlp, InnerTube libraries, transcript tools, hosted APIs and datasets, and the risk each carries for a signed-in account.

## Constraints

### Free mode, without an account

- The channel RSS feed (`https://www.youtube.com/feeds/videos.xml?channel_id=…`) needs no key and no login, and costs no quota: the 15 latest uploads, with the full description, views, likes and thumbnail, but no duration. Shorts are told apart by their `/shorts/` link. It is undocumented and goes down a few times a year, so it needs a fallback ([official §6](official-youtube-api.md#6-free-mode-without-login), [community §9](community-tools-and-account-risk.md#9-recommended-layered-design)).
- Transcripts, chapters and durations come from anonymous calls to YouTube's internal API (InnerTube), as FreeTube does, from the user's own Mac. That is enough to demo the app with no account and no key.
- The official Data API is an optional extra, not the base: its policies forbid shipping an API key in an open-source app, so each user would bring their own ([official §5](official-youtube-api.md#5-sign-in-for-a-native-macos-app)).

### Signed in, with YouTube Premium

- Sign-in goes through Google OAuth in the system browser (loopback redirect and PKCE) or, for a native feel, macOS's `ASWebAuthenticationSession` through a Tauri plugin; Google forbids sign-in inside the app's own webview. The refresh token goes in the Keychain, which keeps the session across launches.
- The session only lasts past 7 days once the Google Cloud app is "In production"; until Google verifies it, users see an "unverified app" screen and new users are capped at 100.
- Signing in adds subscriptions and likes (`youtube.readonly`). Watch history and Watch Later are not in the API: history comes from a Google Takeout import, or the Data Portability API in the EEA, UK and Switzerland, which Google must verify first.
- Premium has no API. Ad-free playback only comes from a youtube.com session inside the embedded player, which WKWebView's cookie rules may prevent; a prototype must settle it before the app promises it ([official §4](official-youtube-api.md#4-youtube-premium-ads-and-the-embedded-player)). The embed needs a `Referer` header, or it shows Error 153.

### Keeping the account safe

- The only documented risk to an account is sending its cookies to a scraper: YouTube can restrict the account for hours to months. Anonymous requests only get the IP rate-limited ([community §8](community-tools-and-account-risk.md#8-account-risk-assessment)).
- So: the Premium session lives only in the player's webview, and the data layer never reads its cookies; every fetch is anonymous and never falls back to cookies; at most one request a second, 5–10 seconds between transcripts, about 200 videos a day; a blocked source pauses for 24 hours.

### Fewer requests

- Each video is fetched once and stored: metadata, transcript, chapters. RSS finds new uploads; details come in batches. With the Data API, 50 channels cost a few units a day out of 10,000 ([official §8](official-youtube-api.md#8-recommended-quota-minimizing-strategy)).

### Policy

- Data taken from the official API must be refreshed or deleted within 30 days, and must not feed "derived data or metrics" such as a score built from likes and views ([official §7](official-youtube-api.md#7-policy-constraints-that-touch-focustube)). Preference learning and summaries should therefore rest on data from RSS and InnerTube, and the store should record where each value came from and when.
- The API policies also forbid scraping in an app that uses the Data API. The risk falls on the Google Cloud project, not on the account; keeping the two layers in separate modules, and the API optional, contains it.

## Decisions to make

- A prototype of Premium playback in a Tauri webview, with the `Referer` set from `tauri://localhost`.
- The runtime of the scraping layer: youtubei.js (MIT) in a sidecar, a Rust port, or yt-dlp (GPLv3+) as a fallback sidecar.
- The app's license: GPL or AGPL dependencies would decide it.
- Whether to publish and verify a Google Cloud app, or have each user bring their own credentials.
- What to do when the anonymous transcript method breaks: yt-dlp, then an opt-in paid API.
