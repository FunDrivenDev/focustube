# Community YouTube data tools and account risk

Research note, 2026-09-27. Scope: the non-official ways to get YouTube data (transcripts, descriptions, chapters, tags, comments, channel uploads, watch history), hosted APIs and datasets, and the risk each one puts on a Google account with YouTube Premium. It answers the open questions of [YouTube data](../features/youtube-data.md) and [Accounts](../features/accounts.md). Facts were checked against primary sources on the date above; anything marked **unverified** comes from memory or a secondary source only.

## Summary

- The one documented account-level danger is sending **your logged-in cookies** to a scraper (yt-dlp, youtubei.js, rustypipe, youtube-transcript-api). A yt-dlp maintainer describes a "fairly significant risk" of a YouTube-side restriction lasting "a few hours to a couple months", with no known threshold ([yt-dlp#15724](https://github.com/yt-dlp/yt-dlp/issues/15724)). Anonymous requests risk only your IP, never the account.
- Rule one for focustube: the Premium session lives only in the official embedded player; every data fetch is anonymous, throttled, cached and done once per video.
- Channel uploads: the public RSS feed (`/feeds/videos.xml?channel_id=`) works today (200, 15 entries, with descriptions, tested 2026-09-27) but goes down a few times a year ([FreeTube#8443](https://github.com/FreeTubeApp/FreeTube/issues/8443), [FreeTube#9196](https://github.com/FreeTubeApp/FreeTube/issues/9196)); fall back to anonymous InnerTube `browse`, then to the Data API (1 unit per `playlistItems.list`).
- Transcripts: anonymous InnerTube `player` (Android client) plus `/api/timedtext`, the youtube-transcript-api approach, works from home IPs but not cloud IPs; web-client caption URLs now need a PO token ([guide, verified 2026-09-13](https://github.com/hxckya/youtube-transcript-ip-blocked-guide)). A paid API (Supadata, 1 credit per transcript) is the clean fallback.
- yt-dlp is the most complete and best maintained tool (release 2026.08.19, commits daily) but needs a JS runtime (Deno) and breaks every few weeks; it is a heavy sidecar for what focustube needs, so treat it as a fallback, not the core.
- Invidious and Piped public instances are unreliable in 2026; FreeTube is the best model for a no-login mode (local subscriptions, RSS or InnerTube fetching, local history).
- Watch history: Google Takeout (manual) or the Data Portability API (official, EEA/UK/CH, France included). Never scrape `/feed/history` with cookies.
- Mixing scraping with the official Data API in one app breaks the YouTube API Developer Policies ("must not ... scrape"); that is a risk to the API project, not to the account, and argues for keeping the two paths separable.

## 1. yt-dlp

**What it gives.** `yt-dlp -J URL` (or `--dump-json`) returns one JSON object per video: title, description, `tags`, `categories`, `chapters` (from the player data, else parsed from timestamps in the description), `channel_id`, `upload_date`, duration, view/like counts, `subtitles` (manual tracks) and `automatic_captions` (auto-generated tracks and their auto-translations, with URLs in json3/srv/vtt formats), thumbnails and formats. `--write-subs --write-auto-subs --sub-langs en,fr --skip-download` downloads captions only; `--write-comments` (with `max_comments` and `comment_sort` extractor args) adds comments; `--flat-playlist` on a channel's `/videos` tab lists uploads without a request per video ([README](https://github.com/yt-dlp/yt-dlp/blob/master/README.md)). The `skip=translated_subs` extractor arg avoids fetching the auto-translated tracks.

**Maintenance and breakage.** Very active: 194k stars, last push 2026-09-27, latest stable 2026.08.19, before it 2026.07.04, 06.09, 03.17, 03.13, 03.03, 02.21, 02.04, 01.31, 01.29 ([releases](https://github.com/yt-dlp/yt-dlp/releases)). Nearly every release carries YouTube "player client maintenance"; 2026.08.19 removed `android_vr` from the default clients and added `visionos` ([2026.08.19](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19)). The issue tracker in September 2026 alone shows 403s on all videos ([#17682](https://github.com/yt-dlp/yt-dlp/issues/17682)), clients becoming SABR-only ([#17666](https://github.com/yt-dlp/yt-dlp/issues/17666)) and a subtitle-parsing crash ([#17662](https://github.com/yt-dlp/yt-dlp/issues/17662)). Expect to ship an update path: a build a few weeks old can fail.

**JavaScript runtime.** Full YouTube support now needs `yt-dlp-ejs` plus a JS runtime, Deno by default (Node, QuickJS, Bun optional); without one yt-dlp warns that "YouTube extraction without a JS runtime has been deprecated" and drops the `web` client ([EJS wiki](https://github.com/yt-dlp/yt-dlp/wiki/EJS), [README](https://github.com/yt-dlp/yt-dlp/blob/master/README.md), [#16747](https://github.com/yt-dlp/yt-dlp/issues/16747)). A missing runtime is a common cause of false "bot" errors in 2026 (#16747).

**PO tokens.** YouTube's Proof-of-Origin token is required for the `web`, `android` and `ios` clients for subtitle requests, and for GVS (video stream) requests on most clients; tokens are now bound to the video ID. Providers: `bgutil-ytdlp-pot-provider` (GPL-3.0, 2.0.0 on 2026-09-08) or `yt-dlp-getpot-wpc` ([PO Token Guide, updated 2026-07-12](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide)). Premium subscribers are exempt from GVS tokens, which only matters for downloading video, not for focustube. Whether yt-dlp's default `visionos` client fetches subtitles without a token is **unverified**; test before relying on it.

**"Sign in to confirm you're not a bot".** YouTube scores each player request by IP and its history, PO token, cookies and request rate, and answers with `LOGIN_REQUIRED` when the score is bad ([#15865](https://github.com/yt-dlp/yt-dlp/issues/15865), Feb 2026, [tunelio explainer](https://tunelio.dev/blog/yt-dlp-sign-in-to-confirm-not-a-bot/)). A maintainer-adjacent reply: YouTube "has been doing [IP blocks] for years", and an IP block shows as "Video unavailable" or the bot message ([#16747](https://github.com/yt-dlp/yt-dlp/issues/16747)). Users report reconnecting the router for a new IP rather than passing cookies ([#15724](https://github.com/yt-dlp/yt-dlp/issues/15724)). The error message itself suggests `--cookies-from-browser`; for focustube that is exactly the path to refuse (section 8).

**Rate limits.** The project wiki gives guest sessions about 300 videos per hour (about 1000 webpage/player requests), accounts about 2000 videos per hour, and recommends a 5 to 10 second delay between downloads (`-t sleep` = `--sleep-subtitles 5 --sleep-requests 0.75 --sleep-interval 10 --max-sleep-interval 20`) ([Extractors wiki](https://github.com/yt-dlp/yt-dlp/wiki/Extractors), [README](https://github.com/yt-dlp/yt-dlp/blob/master/README.md)).

**Cookies.** The wiki warns: "By using your account with yt-dlp, you run the risk of it being banned (temporarily or permanently)", and describes exporting cookies from a private window so they are not rotated ([Extractors wiki](https://github.com/yt-dlp/yt-dlp/wiki/Extractors)). Exported cookies now last 3 to 5 days in some reports ([#13964](https://github.com/yt-dlp/yt-dlp/issues/13964)). Logged-in yt-dlp uses different clients (`web_creator,tv_downgraded,web` for Premium accounts), which changes the traffic pattern tied to the account ([README](https://github.com/yt-dlp/yt-dlp/blob/master/README.md)).

**License and bundling.** The source is Unlicense, but the PyInstaller standalone `yt-dlp_macos` (universal, macOS 10.15+) bundles GPLv3+ code, "and as such the combined work is licensed under GPLv3+" ([README, Licensing](https://github.com/yt-dlp/yt-dlp/blob/master/README.md)). Running it as a separate process (a Tauri `externalBin` sidecar) is aggregation, not linking, so focustube's own license stays free; ship its license text. Costs: a ~35 MB binary (size **unverified**) plus Deno (~40 MB+, **unverified**) for EJS, code-signing and notarizing both inside the app bundle, and an updater, because a stale yt-dlp breaks within weeks. Alternative: download yt-dlp on first use into Application Support and self-update (`yt-dlp -U`), which avoids shipping and notarizing it but runs unsigned code downloaded at runtime (**unverified** whether the hardened runtime allows it without a quarantine prompt).

**Rust-native alternatives.**

| Crate | State (crates.io / repo) | Notes |
| --- | --- | --- |
| [`rusty_ytdl`](https://github.com/Mithronn/rusty-ytdl) | 0.7.4 (2024-08-10), repo commits Jan 2026, MIT | Port of node-ytdl-core, stream-oriented, stale release; not a data tool. |
| [`rustypipe`](https://codeberg.org/ThetaDev/rustypipe) | 0.11.4 (2025-04-23), last code commit 2025-06-18, GPL-3.0 | Full InnerTube client (player with subtitles, channels, playlists, search, comments, cookie/OAuth auth, `rustypipe-botguard` for PO tokens). Best Rust option, but slow maintenance and GPL. |
| [`yt-transcript-rs`](https://github.com/akinsella/yt-transcript-rs) | 0.1.8 (2025-06-24) | Port of youtube-transcript-api, InnerTube-only since 0.1.8; stale for YouTube's pace. |
| [`yt-dlp`](https://github.com/boul2gom/yt-dlp) | 2.8.3 (2026-08-17), GPL-3.0 | Rust wrapper that downloads and drives the yt-dlp binary; convenient for the sidecar path. |
| `ytt`, `ytranscript`, `youtube-transcript`, `ytsrt` | small, 2023 to 2026 | Hobby crates, low downloads ([crates.io search](https://crates.io/search?q=youtube%20transcript)). |

No Rust crate is maintained at yt-dlp's or youtubei.js's pace. Writing the two or three InnerTube calls focustube needs in Rust (`player` for caption tracks, `browse` for a channel's videos, `next` for description and chapters) is small, but focustube would own the breakage.

## 2. Transcript libraries

**youtube-transcript-api (Python).** MIT, 8.4k stars, latest 1.2.4 on 2026-01-29, commits through 2026-09-10 ([repo](https://github.com/jdepoix/youtube-transcript-api), [PyPI](https://pypi.org/project/youtube-transcript-api/)). It fetches the watch page for the InnerTube key, POSTs `/youtubei/v1/player` (the Android client since 1.1.0), reads `captions.playerCaptionsTracklistRenderer.captionTracks`, then downloads `/api/timedtext` ([hxckya guide](https://github.com/hxckya/youtube-transcript-ip-blocked-guide)). Features: manual and auto-generated tracks, language priority lists, translation, JSON/SRT/WebVTT output. Cookie authentication "is currently not available" because YouTube changes broke it, so the library is anonymous by construction, which suits focustube. It documents that YouTube blocks "most IPs that are known to belong to cloud providers", raising `RequestBlocked`/`IpBlocked`, and recommends Webshare residential proxies ([README](https://github.com/jdepoix/youtube-transcript-api)); a May 2026 report confirms "works locally, blocked on AWS" ([#593](https://github.com/jdepoix/youtube-transcript-api/issues/593)).

**PO token on captions.** Web-client caption URLs now carry `exp=xpe` and returned 0 bytes without a PO token in a test on 2026-09-13, while Android-client URLs still worked; Android downloads occasionally return empty bodies too, and the libraries cannot tell "captions disabled" from "blocked" ([hxckya guide](https://github.com/hxckya/youtube-transcript-ip-blocked-guide), an independent guide, not the maintainers). This is the most fragile point of the anonymous transcript path: if YouTube extends PO tokens to the Android client, every library without BotGuard support breaks at once.

**JavaScript equivalents.** `youtube-transcript` (npm, 1.3.1 on 2026-04-25, [repo](https://github.com/Kakulukian/youtube-transcript)) mirrors the Python approach. `youtubei.js` exposes the transcript panel through `/youtubei/v1/get_transcript` (`TranscriptInfo`, with `selectLanguage`) ([source](https://github.com/LuanRT/YouTube.js/blob/main/src/parser/youtube/TranscriptInfo.ts)); that endpoint takes protobuf `params` found on the watch page ([Invidious#2564](https://github.com/iv-org/invidious/issues/2564)).

**Rust.** See section 1: `yt-transcript-rs` or `rustypipe` (player response includes subtitle tracks), or a hand-written `player` + `timedtext` call.

**Reliability in 2026.** From a residential IP at personal volumes, the anonymous path works; failures come in waves when YouTube changes clients or tokens. From any cloud IP it does not work without residential proxies. Plan for a fallback (yt-dlp, then a paid API) and for "no transcript" being a legitimate state.

## 3. InnerTube

InnerTube is the JSON API (`https://www.youtube.com/youtubei/v1/...`) that YouTube's own web, Android, iOS and TV clients call. The endpoints that matter:

| Endpoint | Returns |
| --- | --- |
| `player` | `videoDetails` (title, `shortDescription`, `keywords` = tags, channel, length), `microformat` (publish date, category), `captions` (tracks with language, `kind: asr` for auto-generated), streaming data (needs PO token and signature solving) |
| `next` | Watch-page data: full description with links, chapters (macro markers), engagement panels (transcript entry, comments entry), related videos |
| `browse` | Channel tabs (`/videos`, `/streams`, `/shorts`, `/playlists`), playlists, and, with cookies, `FEhistory` (watch history), `FEsubscriptions`, library |
| `get_transcript` | The transcript panel's segments with timestamps |
| `search`, `resolve_url` | Search, handle to channel ID resolution |

**Libraries.** `youtubei.js` (MIT, v18.1.0 on 2026-09-22, monthly releases, [repo](https://github.com/LuanRT/YouTube.js), [releases](https://github.com/LuanRT/YouTube.js/releases)) is the most complete: `getInfo`, `getBasicInfo`, `getChannel`, `getComments`, `getHistory`, `getSubscriptionsFeed`, `getLibrary`, plus write actions such as `addToWatchHistory` and `like` ([API docs](https://www.ytjs.dev/api/classes/Innertube), [VideoInfo source](https://github.com/LuanRT/YouTube.js/blob/main/src/parser/youtube/VideoInfo.ts)); PO tokens come from `BgUtils` (MIT, v4.0.3 on 2026-08-04). NewPipe Extractor (Java, GPL-3.0, v0.26.5 on 2026-08-15, [releases](https://github.com/TeamNewPipe/NewPipeExtractor/releases)) powers NewPipe and Piped. Invidious (Crystal, AGPL-3.0) now delegates player requests to `invidious-companion` (Deno/TypeScript, AGPL-3.0) since v2.20250913.0 ([releases](https://github.com/iv-org/invidious/releases)). `rustypipe` is the Rust option.

**Running youtubei.js in focustube.** It runs in a browser, but the WKWebView front end cannot call `youtube.com/youtubei` directly because of CORS; it would need a Rust proxy command, or running youtubei.js under Deno as a sidecar (Deno is already needed for yt-dlp's EJS). **Unverified** which is simpler; a prototype should decide.

**Risk with cookies.** Every InnerTube call carrying the account's `SAPISID`/`__Secure-3PSID` cookies is attributed to the account. Unlike the official player, a library's traffic differs (client versions, missing BotGuard attestation, request pacing), which is exactly the signal that got accounts restricted in the yt-dlp reports ([#10085](https://github.com/yt-dlp/yt-dlp/issues/10085), 2024: accounts "blocked from web", users "banned using the web client"; [#15724](https://github.com/yt-dlp/yt-dlp/issues/15724), 2026). Write endpoints (`addToWatchHistory`, likes) with an automated client are riskier still. Anonymous InnerTube requests carry only a `visitorData` identifier and the IP.

## 4. Front-end alternatives and proxies

| Project | State, 2026 | Useful to focustube |
| --- | --- | --- |
| [Invidious](https://github.com/iv-org/invidious) | Active (v2.20260804.1, push 2026-09-25), AGPL-3.0. Public instances face "CAPTCHAs, throttling, and outright blacklisting"; self-hosting on a home IP still works ([sumguy, 2026-09](https://sumguy.com/invidious-piped-redlib-nitter-2026/)). Instances can now disable the API (v2.20260723.0). | REST API: `/api/v1/videos/:id` (description, captions list), `/api/v1/captions/:id` (WebVTT), `/api/v1/comments/:id`, `/api/v1/channels/:id` ([API docs](https://docs.invidious.io/api/)). Public instances: unreliable, and the instance sees your IP and queries. |
| [Piped](https://github.com/TeamPiped/Piped) | Frontend push 2026-09-25, backend commits to May 2026 then sparse; the official instance's feed does not load and other instances show "IP blocked" or the bot check, "since 2024" per [Piped#4257](https://github.com/TeamPiped/Piped/issues/4257). Holds up better than Invidious for playback per [sumguy](https://sumguy.com/invidious-piped-redlib-nitter-2026/). | `/streams/:id` (description, subtitles, uploader), `/comments/:id`, `/channel/:id` ([API docs](https://docs.piped.video/docs/api-documentation/)). Same caveats. |
| [FreeTube](https://github.com/FreeTubeApp/FreeTube) | Active (v0.25.3-beta on 2026-08-28, push 2026-09-27), AGPL-3.0, Electron desktop. | The closest model for focustube's free mode (below). |
| [NewPipe](https://github.com/TeamNewPipe/NewPipe) | Active (v0.29.1 on 2026-08-15), GPL-3.0, Android only, no login by design. Added an FAQ link for the bot error in March 2026 ([#13310](https://github.com/TeamNewPipe/NewPipe/pull/13310)). | Its extractor, not the app. |

**How FreeTube does subscriptions without login.** Subscriptions, history and playlists live in local files; nothing is sent to Google except the fetches. For the feed it uses either YouTube's RSS feeds or the "local API" (youtubei.js InnerTube calls from the user's IP). Since July 2026 it fetches via InnerTube in batches instead of forcing RSS above a subscription count; the maintainers do not know YouTube's thresholds ("we can never be sure about how YT setup their rate limiting") and picked about 80 channels per batch ([PR #9379](https://github.com/FreeTubeApp/FreeTube/pull/9379)). RSS outages happen "a few times each year and are usually back within a day or two" (maintainer in [#8443](https://github.com/FreeTubeApp/FreeTube/issues/8443), Dec 2025); users reported near-daily RSS failures in May 2026 ([#9196](https://github.com/FreeTubeApp/FreeTube/issues/9196)) and a platform-wide outage on 2026-02-13 to 17 ([ocaml.org#3512](https://github.com/ocaml/ocaml.org/issues/3512)). FreeTube's releases warn that relying on HTML page data may trigger YouTube's CAPTCHA ([v0.25.3-beta](https://github.com/FreeTubeApp/FreeTube/releases/tag/v0.25.3-beta)). Lesson for focustube: keep the last good feed on failure, use RSS first and InnerTube as fallback, and never hammer every channel when one fails.

## 5. Hosted APIs and datasets

| Service | What | Price (checked 2026-09-27) | Notes |
| --- | --- | --- | --- |
| [Supadata](https://supadata.ai/pricing) | Transcript (existing captions), channel/playlist video lists, metadata, AI transcription when no captions | Free 100 credits/month; Basic $5/month (annual) 300; Pro $17 for 3,000; transcript = 1 credit, AI transcript = 2 credits per minute | Cited as the working fallback in [youtube-transcript-api#593](https://github.com/jdepoix/youtube-transcript-api/issues/593). |
| [SearchAPI.io](https://www.searchapi.io/docs/youtube-transcripts) | `youtube_transcripts` (auto or manual, `lang`), also `youtube_video`, `youtube_comments`, channel videos | 100 free requests; from $40/month for 10,000 ([pricing](https://www.searchapi.io/pricing)) | |
| [SerpApi](https://serpapi.com/youtube-video-transcript) | `youtube_video_transcript` (segments, ms timings, chapters, track choices), `youtube_video` (description, chapters, comments links) | 250 free searches/month; $25/month for 1,000 ([pricing](https://serpapi.com/pricing)) | Cached results for 1 h are free. |
| [Apify YouTube Scraper](https://apify.com/streamers/youtube-scraper) | Videos, channels, subtitles | $2.40 per 1,000 videos | Actor quality varies across the store. |
| [youtube-transcript.io](https://www.youtube-transcript.io/pricing) | Transcripts, API on paid plans | Free 25/month; $9.99 for 1,000 | |
| [TranscriptAPI](https://transcriptapi.com/pricing) | Transcripts, channel videos, search | Pricing page did not render; **unverified** | |
| RapidAPI transcript APIs, Tactiq | Many small resellers; Tactiq is a meeting/extension product with a free web tool | **Unverified**; no public API found for Tactiq | Provenance unknown: avoid. |

All of them scrape YouTube from rotating residential proxies; the legal exposure is theirs (SerpApi sells "Legal Shield" on higher plans), and none touches the user's account. For a personal app: a few hundred transcripts a month fit the free or $5 tiers; it costs money and an API key, sends video IDs to a third party (privacy note for [local first](../mission.md)), and needs an account the user creates. Good as an opt-in fallback, not as the default.

**Datasets.** None is useful for a feed of recent videos from chosen channels; they are frozen research corpora.

- [YouTube-Commons](https://huggingface.co/datasets/PleIAs/YouTube-Commons) (PleIAs): 2.06 M CC-BY videos, 22.7 M original and translated transcripts, CC-BY-4.0. The only one with clean licensing; coverage of a given creator is luck.
- [YT-Temporal-1B](https://rowanzellers.com/merlotreserve/): 20 M video IDs with titles and descriptions; no transcripts or clear license on the page.
- [VidChapters-7M](https://antoyang.github.io/vidchapters.html): 817 K videos with user chapters and ASR, 2023.
- HowTo100M, YouTube-8M: older, IDs and features only (**unverified** details, not checked).

## 6. Watch history without the Data API

The Data API has no watch-history endpoint (the history playlist was removed years ago; **unverified** date, widely known).

| Method | Format | Tradeoffs |
| --- | --- | --- |
| Google Takeout, "YouTube and YouTube Music > history" | `watch-history.json` (or `.html`): array of `{header: "YouTube", title: "Watched …", titleUrl, subtitles: [{name, url}], time, products, activityControls}`; fields are omitted for deleted videos; no watch duration or resume point ([Playback Stats guide](https://playbackstats.com/guides/youtube-watch-history-json)); ad views appear with a `details` "From Google Ads" entry (**unverified**) | Zero risk, official, full history. Manual: the user exports, downloads a zip, drops it in focustube. Scheduled exports every 2 months for a year exist in Takeout (**unverified** for YouTube). |
| [Data Portability API](https://developers.google.com/data-portability) | Same My Activity JSON, scope `dataportability.myactivity.youtube`, time filters, one-time or 30/180-day access ([schema](https://developers.google.com/data-portability/schema-reference/my_activity), [release notes](https://developers.google.com/data-portability/docs/release-notes)); also `dataportability.youtube.subscriptions` (sensitive) ([scopes](https://developers.google.com/data-portability/user-guide/scopes)) | Official, zero account risk, automatable. Only for users in the EEA, Switzerland and the UK (France included) ([Google help](https://support.google.com/accounts/answer/14452558?hl=en)); not for under-18s, managed or Advanced Protection accounts; the app needs Google's OAuth verification before public release (demo video, privacy policy, possibly a security assessment) ([overview](https://developers.google.com/data-portability/user-guide/overview)). Whether `myactivity.youtube` is sensitive or restricted is **unverified**. For a single developer using their own OAuth client in "testing" mode, verification is not required for up to 100 test users (**unverified** for this API). |
| Cookie scraping of `/feed/history` (InnerTube `browse` `FEhistory`, youtubei.js `getHistory`) | Rich, incremental | High account risk (section 8). Reject. |

Recommendation: Takeout import in v1 (works everywhere), Data Portability API later for EEA users who want automatic sync.

## 7. Show notes: which tool gets which

| Data | RSS | InnerTube anonymous (youtubei.js, rustypipe) | yt-dlp | youtube-transcript-api | Invidious/Piped API | Data API v3 |
| --- | --- | --- | --- | --- | --- | --- |
| Title, publish date, thumbnail, views | yes (15 latest) | yes | yes | no | yes | yes, 1 unit |
| Full description with links | yes, `media:description` (15 latest) | yes (`player` short description, `next` with links) | yes | no | yes | yes |
| Chapters | no (parse description timestamps) | yes (`next` markers) | yes (`chapters`) | no | Piped `chapters` (**unverified**), Invidious via description | no (parse description) |
| Tags | no | yes (`keywords`) | yes (`tags`) | no | yes | yes (`snippet.tags`) |
| Transcripts, manual and auto, languages, timestamps | no | yes (caption tracks, `get_transcript`) | yes (`subtitles`, `automatic_captions`) | yes | yes (WebVTT) | only for your own videos |
| Comments, pinned comment | no | yes (`getComments`; pinned flag in thread renderer) | yes (`--write-comments`; `is_pinned` field, **unverified** name) | no | yes | yes (`commentThreads`, 1 unit; pinned status not exposed, **unverified**) |
| Channel uploads (all) | no | yes (`browse` videos tab, paginated) | yes (`--flat-playlist`) | no | yes | yes (`playlistItems` on the `UU…` uploads playlist, 1 unit per 50) |

Links in descriptions are plain text: extract URLs with a regex and resolve them in the [references](../features/references.md) step. A pinned comment often holds show notes on podcasts; fetch the first comment page only when the description has no links, to save requests. The `UULF…` playlist prefix lists long-form uploads without Shorts (community knowledge, **unverified**, seen in [FreeTube#8443](https://github.com/FreeTubeApp/FreeTube/issues/8443)).

## 8. Account risk assessment

**What YouTube's terms say.** The Terms of Service forbid to "access the Service using any automated means (such as robots, botnets or scrapers)" except public search engines under robots.txt or with written permission, and to "access, reproduce, download … any part of the Service or any Content" except as permitted, and to "circumvent, disable, fraudulently engage with, or otherwise interfere with any part of the Service"; YouTube may terminate an account that "materially or repeatedly" breaches the agreement ([Terms](https://www.youtube.com/static?template=terms&hl=en&gl=US); the French version is effective 2026-01-09, [fr](https://www.youtube.com/t/terms)). Every scraping method in this note is outside the terms; the question is who bears the consequence. If focustube also uses the Data API, the [Developer Policies](https://developers.google.com/youtube/terms/developer-policies) add that API clients "must not … scrape YouTube Applications" and "must not use any technology other than YouTube API Services to access or retrieve API Data", and cap storage of API data at 30 days before refresh or deletion; the sanction there falls on the API project (quota revocation), not the Premium account.

**IP-level versus account-level action.** Two separate enforcement systems appear in the record:

- IP-level: anonymous requests get "Sign in to confirm you're not a bot", "Video unavailable", 403s or throttling (one user was limited to 40 kB/s) for the IP, lasting hours to days; cloud and VPN ranges are blocked outright ([#16747](https://github.com/yt-dlp/yt-dlp/issues/16747), [#10085](https://github.com/yt-dlp/yt-dlp/issues/10085), [youtube-transcript-api README](https://github.com/jdepoix/youtube-transcript-api)). Nothing in the record ties these to an account. Whether Google links a flagged home IP to the signed-in account using the same IP is **unverified**; no report of account action from anonymous scraping was found.
- Account-level: when cookies are sent with automated requests, "there is a fairly significant risk that your account will be 'restricted': you won't be able to watch any videos with the account outside of the official Android YT app … These account 'restrictions' can last anywhere from a few hours to a couple months. There is no known threshold." It "does not affect your Google account outside of watching YouTube videos. However, there is a much, much smaller risk that action may be taken against your entire Google account." Permanent bans were reported only for accounts "created … for the sole purpose of downloading" (bashonly, yt-dlp maintainer, 2026-01-28, [#15724](https://github.com/yt-dlp/yt-dlp/issues/15724)). The June 2024 wave ([#10085](https://github.com/yt-dlp/yt-dlp/issues/10085)) blocked heavily used accounts from the web `/player` endpoint; removing the cookie restored anonymous access. A community Discord note: "DO NOT login with an important Google account (such as an account you use for Gmail)" ([#13964](https://github.com/yt-dlp/yt-dlp/issues/13964)).
- Ad blocking: YouTube's 2023 to 2025 campaign against ad blockers and ad-blocking third-party apps led to warnings, buffering, blocked playback and "content is not available on this app" messages, not documented account suspensions ([gHacks, 2025-03](https://www.ghacks.net/2025/03/18/google-pushing-ad-blockers-violate-youtubes-terms-of-service-banners-on-youtube/), [Thurrott, 2024](https://www.thurrott.com/music-videos/300878/youtube-starts-cracking-down-on-third-party-ad-blocking-apps)). Irrelevant with Premium, but modifying the player to hide YouTube UI inside a signed-in session would be the same category of "interference".
- NewPipe, FreeTube, Piped, Invidious: no login to Google at all (their accounts are local), so no account-level record exists for them.

**Ratings for the Premium account.**

| Method | Account risk | Why |
| --- | --- | --- |
| Official IFrame player in the app's WKWebView, signed in | None | Ordinary use; Premium applies to embeds when signed in, since "embedded videos will honor the same ad enablement settings" ([help](https://support.google.com/youtube/answer/132596?hl=en-premium)). Tauri production builds need a valid referrer or embeds fail with Error 153 ([tauri#14422](https://github.com/tauri-apps/tauri/issues/14422), [Simon Willison](https://til.simonwillison.net/youtube/fixing-153-embed)). |
| Data API with OAuth `youtube.readonly` | None | Official; quota and Developer Policies apply to the project. |
| Takeout, Data Portability API | None | Official exports. |
| RSS feeds, anonymous | None (IP: very low) | Public endpoint meant for feed readers. |
| Anonymous InnerTube / youtube-transcript-api / rustypipe from home IP, throttled | None (IP: low) | No account identifiers sent. |
| yt-dlp anonymous from home IP | None (IP: low to medium) | Heavier request pattern (webpage, player, JS challenge). |
| Hosted APIs (Supadata etc.) | None | Traffic comes from their IPs. |
| Public Invidious/Piped instances | None (privacy: instance sees IP and video IDs) | |
| Any scraper with the account's cookies (yt-dlp `--cookies-from-browser`, youtubei.js signed in, rustypipe cookie auth) | High | Documented restrictions, hours to months. |
| Scraping `/feed/history` or subscriptions with cookies | High | Same, plus repeated signed-in automation. |
| Injecting scripts/CSS into signed-in youtube.com pages to hide UI or automate clicks | Medium (**unverified**, no case found) | Same session as Premium; automation signals are attributed to the account. |

**Rules for focustube.**

1. The Premium session exists only in the player webview. No code path reads, exports or forwards its cookies; the data layer uses a separate HTTP client with no cookie jar shared with the webview (a separate `WKWebsiteDataStore` or none).
2. All scraping is anonymous: no `SAPISID`, no OAuth token, no `--cookies-from-browser`, ever. If YouTube answers with the bot wall, back off; never escalate to cookies. Make this a code-level invariant with a test.
3. Throttle below FreeTube's and yt-dlp's comfort zone: at most 1 request per second overall, 5 to 10 seconds between transcript fetches (yt-dlp's own advice), a daily budget of about 200 videos analyzed and 300 channel refreshes (focustube's own numbers, conservative against the ~300 videos per hour guest limit), random jitter, no parallel bursts.
4. Refresh on launch and on demand only, never in a loop (already in [YouTube data](../features/youtube-data.md)); each channel at most every 1 to 3 hours.
5. Cache everything forever that does not change (transcripts, chapters, descriptions of published videos); fetch each video once. Keep negative results (no captions, private, removed) with a retry date.
6. On a block (bot wall, 429, empty body in a row), stop that source for 24 hours, tell the user, and switch to the next layer; do not retry in a loop.
7. No VPN or datacenter proxy for anonymous fetching: they worsen the bot score.
8. Keep an update channel for whichever extractor ships (yt-dlp or a Rust client): breakage is a when, not an if.
9. Keep data provenance per row: Data API rows follow the 30-day policy, scraped rows do not mix into the API path.

## 9. Recommended layered design

**Free mode (no login, demo).**

| Need | First | Fallback 1 | Fallback 2 |
| --- | --- | --- | --- |
| Resolve a channel URL or handle | Parse the URL; fetch the channel page anonymously once for `channel_id` | InnerTube `resolve_url` | Ask for the channel ID |
| New uploads | RSS per channel (15 latest with descriptions) | Anonymous InnerTube `browse` videos tab (FreeTube's batched approach) | Keep the last good feed, show "stale since" |
| Backfill of older uploads | Anonymous InnerTube `browse` paginated, on demand | yt-dlp `--flat-playlist` | |
| Description, tags, chapters, duration | RSS description; anonymous `player` + `next` once per video | yt-dlp `-J` | |
| Transcript | Anonymous `player` (Android client) caption tracks + `timedtext`, preferring manual over `asr` in the theme's language | yt-dlp `--write-subs --write-auto-subs --skip-download` | Opt-in paid API (Supadata) with the user's own key |
| Pinned comment | First comment page, only if the description has no links | | |
| History | Local only: what the user opens in focustube | Takeout import | |

**Signed-in mode (Google OAuth + Premium playback).** Everything above stays the same and stays anonymous. Additions: import subscriptions once with the Data API (`subscriptions.list`, 1 unit per 50) or the Data Portability API; history through Takeout or the Data Portability API (EEA); playback in the official embed signed in, so Premium removes ads. The Data API is a quota-bounded fallback for uploads (`playlistItems.list` on the uploads playlist, 1 unit) and metadata (`videos.list`, 1 unit for 50 IDs), not the main path; with a 10,000 units/day quota that covers hundreds of channels, but keep the scraping and API paths in separate modules so the API path can be shipped alone if policy requires it.

**What to store in SQLite so each video is fetched once.**

- `channel`: `channel_id`, handle, title, `uploads_playlist_id`, `rss_etag`/last-modified, `last_checked_at`, `last_seen_video_id`, `next_check_after`.
- `video`: `video_id` (PK), `channel_id`, title, `published_at`, `duration_s`, `is_short`, `is_live`, description, `tags` (JSON), `chapters` (JSON: start, title), `links` (JSON, extracted from description and pinned comment), `metadata_source` (`rss`, `innertube`, `ytdlp`, `data_api`), `metadata_fetched_at`, `availability` (public, private, removed, members).
- `transcript`: `video_id`, `lang`, `kind` (`manual`, `asr`, `translated`), `segments` (JSON: start_ms, dur_ms, text), `source`, `fetched_at`; plus `transcript_status` per video (`ok`, `none`, `blocked`, `retry_after`).
- `comment_snapshot`: `video_id`, pinned comment text and author, `fetched_at` (optional).
- `watch_event`: `video_id`, `watched_at`, `source` (`app`, `takeout`, `dataportability`), import batch ID, deduplicated on (`video_id`, `watched_at`).
- `fetch_log`: source, endpoint, status, latency, `at`; drives the throttle, the daily budget and the 24-hour circuit breaker per source.
- `api_quota`: day, units used (already planned in [Storage](../features/storage.md)).

Raw responses are not worth keeping beyond debugging; the parsed rows are the cache.

## Comparison

| Tool | Data | Auth | Reliability 2026 | Maintenance | Account risk | License |
| --- | --- | --- | --- | --- | --- | --- |
| YouTube RSS feeds | 15 latest uploads, descriptions | None | Good, outages a few times a year (Feb 2026 multi-day) | Google, undocumented | None | n/a (YouTube ToS) |
| YouTube Data API v3 | Metadata, uploads, comments, subscriptions; no transcripts or history | API key / OAuth | Stable, 10,000 units/day | Google | None | Developer Policies |
| yt-dlp | Everything (metadata, subs, auto-subs, chapters, comments, channel lists) | None; cookies optional | Works, breaks every few weeks; needs Deno and sometimes PO tokens | Very active, releases monthly | None anonymous; High with cookies | Unlicense source, GPLv3+ binaries |
| youtube-transcript-api | Transcripts, languages, translation | None (cookies broken) | Works from home IPs; cloud IPs blocked; PO token creeping in | Active, last release Jan 2026 | None | MIT |
| youtube-transcript (npm) | Transcripts | None | As above | Low activity, 1.3.1 Apr 2026 | None | not declared on GitHub |
| youtubei.js | Full InnerTube: player, next, browse, comments, transcript panel, history with login | None; cookies/OAuth optional | Works, fast fixes | Active, v18.1.0 Sep 2026 | None anonymous; High signed in | MIT |
| rustypipe | InnerTube in Rust: player with subtitles, channels, comments, cookie auth | None; cookies/OAuth optional | **Unverified** in 2026 | Slow, last code commit Jun 2025 | None anonymous; High with cookies | GPL-3.0 |
| rusty_ytdl | Video info and streams | None | **Unverified**, stale release | Low | None | MIT |
| NewPipe Extractor | Full, Java | None | Works | Active, v0.26.5 Aug 2026 | None | GPL-3.0 |
| Invidious (public) | Videos, captions, comments, channels via REST | None | Poor on public instances; self-host OK | Active | None (privacy exposure) | AGPL-3.0 |
| Piped (public) | Streams, subtitles, chapters, comments via REST | None | Mixed, feed broken on official instance | Frontend active, backend slow | None (privacy exposure) | AGPL-3.0 |
| FreeTube | Model for local subscriptions | None | Works, RSS and InnerTube fallback | Active | None | AGPL-3.0 |
| Supadata | Transcripts, channel lists, metadata, AI transcripts | API key | Good (vendor) | Commercial | None | Commercial |
| SearchAPI / SerpApi | Transcripts, video, comments | API key | Good (vendor) | Commercial | None | Commercial |
| Apify actors | Videos, channels, subtitles | API key | Varies by actor | Third parties | None | Commercial |
| YouTube-Commons | 2 M CC-BY transcripts, frozen | None | Static | Research | None | CC-BY-4.0 |
| Google Takeout | Watch and search history, subscriptions | Manual export | Stable | Google | None | n/a |
| Data Portability API | My Activity (history), subscriptions | OAuth, EEA/UK/CH | Stable | Google | None | Google API terms |
| Cookie scraping of history | History, subscriptions | Account cookies | Works until flagged | n/a | High | n/a |

## Open questions

- Does the anonymous Android-client caption path keep working through 2026, or does YouTube extend PO tokens to it? A small canary (one known video per day) would detect it before users do.
- Which runtime for the scraping layer: a Rust InnerTube module written in-house, rustypipe (GPL-3.0), or youtubei.js under Deno as a sidecar (MIT, fastest fixes)? focustube declares no license yet; GPL/AGPL dependencies linked into the app would decide it.
- Is shipping yt-dlp plus Deno as notarized sidecars worth it for a fallback, or should yt-dlp be an optional "power user" download? Binary sizes and hardened-runtime behaviour are **unverified**.
- Does Google correlate an IP flagged for anonymous scraping with the Premium account signed in from the same IP? No evidence either way was found.
- Is `dataportability.myactivity.youtube` a sensitive or restricted scope, and can a personal OAuth client in testing mode use it without verification?
- Does using the Data API in the same app as anonymous scraping put the API project at risk in practice (the policy text says yes; enforcement on small desktop apps is **unverified**)?
- Does the IFrame player in Tauri's WKWebView keep the Premium sign-in across launches, and does the Error 153 referrer fix hold in production builds?
