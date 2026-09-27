# What the official YouTube and Google APIs allow

Research note, 2026-09-27. Scope: only what Google officially provides (YouTube Data API v3, IFrame player, official feeds, OAuth, Data Portability API, Takeout, other Google APIs). Unofficial routes (timed-text endpoint, `yt-dlp`, InnerTube) are out of scope and covered separately. Every claim links its source; claims tested by hand on 2026-09-27 are marked **(tested)**; claims not confirmed by a primary source are marked **(unverified)**.

Answers the open questions in [YouTube data](../features/youtube-data.md) and [Accounts](../features/accounts.md).

## Summary

- Quota is not the problem: at 1 unit per `videos.list`/`playlistItems.list`/`channels.list` call, a 50-channel feed costs roughly 5 to 60 units a day out of 10,000. Since 2026-06-01, `search.list` has its own bucket of 100 calls a day at 1 unit each, instead of 100 units per call.
- The channel RSS feed (`/feeds/videos.xml?channel_id=`) works without a key or login, returns the latest 15 uploads, and is cached for 15 minutes. It is the free discovery channel.
- Transcripts of other people's videos cannot be obtained through the YouTube Data API: `captions.download` needs edit rights on the video. The only official Google route to a transcript or summary of a public video is the Gemini API, which accepts YouTube URLs (in preview).
- Watch history and Watch Later are not available through the Data API (removed in 2016). Subscriptions, liked videos and playlists are available with `youtube.readonly`. History comes only through Takeout (manual, worldwide) or the Data Portability API (EEA, Switzerland and UK only; restricted scope; verification).
- There is no Premium API. Ad-free playback in an embed depends only on a youtube.com cookie session inside the player's webview. Google may block sign-in inside embedded webviews, and WebKit blocks third-party cookies, so Premium-in-Tauri is unproven. `rel=0` cannot hide related videos any more.
- The policies forbid embedding API credentials in open-source projects. Each user brings their own API key and OAuth client, or the project runs a backend.
- Refresh tokens expire after 7 days only while the OAuth app is in "Testing"; an app "In production" but unverified keeps its tokens, shows an "unverified app" screen, and is capped at 100 new users.
- Storage rule: API data (metadata, statistics) must be refreshed or deleted within 30 days, and there is a broad ban on "derived data or metrics" built from API data. That ban is the main policy risk for preference learning. Your own notes, feedback and summaries of non-API content are not API data.

## 1. YouTube Data API v3: data, auth and quota

### Available fields

- **Video** ([resource](https://developers.google.com/youtube/v3/docs/videos)):
  - `snippet`: title, description, tags, categoryId, thumbnails up to `maxres`, plus `fhd`/`qhd`/`uhd` on some videos since 2026-09-11 ([revision history](https://developers.google.com/youtube/v3/revision_history)); also channelId, channelTitle, publishedAt, defaultLanguage, defaultAudioLanguage, liveBroadcastContent and localized.
  - `contentDetails`: duration (ISO 8601), definition, dimension, `caption` ("true"/"false": whether captions exist), licensedContent, regionRestriction and contentRating.
  - `statistics`: viewCount, likeCount and commentCount. `dislikeCount` is private to the owner since 2021-12-13, and favoriteCount is always 0.
  - `status`: privacyStatus, embeddable, madeForKids, license, containsSyntheticMedia and others.
  - `topicDetails`: `topicCategories` (Wikipedia URLs) and `relevantTopicIds`; `topicIds` is deprecated.
  - `liveStreamingDetails`: scheduled and actual start and end times, concurrentViewers.
  - Also `player.embedHtml`, `recordingDetails.recordingDate`, `paidProductPlacementDetails`, `localizations` and, since 2026-07-07, `brandPartner`.
  - Owner-only: `fileDetails`, `processingDetails`, `suggestions`.
- **No chapters field.** Chapters are timestamps written in the description, so they must be parsed from `snippet.description` (same resource page; no chapter property exists).
- **Shorts:** the API has no Shorts flag (no property in the resource).
- **`videos.batchGetStats`** (new on 2026-06-03): statistics, duration and publish time for a list of IDs, at 1 unit, in its own bucket of 10,000 units a day. No auth is needed for public videos ([doc](https://developers.google.com/youtube/v3/docs/videos/batchGetStats), [revision history](https://developers.google.com/youtube/v3/revision_history)).
- **Channel** ([resource](https://developers.google.com/youtube/v3/docs/channels)):
  - snippet, `contentDetails.relatedPlaylists.uploads` (the uploads playlist, "UU…"), statistics (subscriberCount rounded to 3 significant figures), topicDetails, brandingSettings and status.
  - Lookup: `channels.list` with `forHandle=@handle` resolves a handle to a channel ([doc](https://developers.google.com/youtube/v3/docs/channels/list)).
- **Playlist items:** `playlistItems.list`, up to 50 per page ([doc](https://developers.google.com/youtube/v3/docs/playlistItems/list)).

### API key or OAuth

All public reads work with an API key: `videos.list` by id, `channels.list`, `playlistItems.list`, `search.list`, `activities.list` with `channelId`, and `batchGetStats`.

OAuth is required for:

- anything `mine`: `subscriptions.list?mine=true`, `playlists.list?mine=true`;
- `videos.list?myRating=like`, limited to 1,000 results ([doc](https://developers.google.com/youtube/v3/docs/videos/list));
- `videos.getRating`, which accepts `youtube.readonly` since 2026-09-01 ([revision history](https://developers.google.com/youtube/v3/revision_history));
- all captions methods;
- all writes.

### Quota

Source: [quota calculator](https://developers.google.com/youtube/v3/determine_quota_cost), updated 2026-09-15.

- **Buckets:** by default, 10,000 units a day for all methods combined, plus separate buckets of 100 `search.list` calls and 100 `videos.insert` calls. Quotas reset at midnight Pacific time.
- **1 unit:** every `list` call (activities, channels, playlistItems, playlists, subscriptions, videos, commentThreads, videoCategories), `videos.getRating`, and `search.list` (in its own bucket).
- **50 units:** most writes, and `captions.list`.
- **200 units:** `captions.download` ([doc](https://developers.google.com/youtube/v3/docs/captions/download)).
- **Every request costs at least 1 unit, invalid ones included, and each extra page is billed again.**
- **History:** the granular buckets (search 1 unit, 100 a day) date from 2026-06-01. Before that, `search.list` cost 100 units per call ([revision history](https://developers.google.com/youtube/v3/revision_history)).

### Getting more quota

Complete the "YouTube API Services – Audit and Quota Extension Form". YouTube runs an API Compliance Audit against the use case you declare. Approved quota may only serve that use case, and projects inactive for 90 days may lose their quota ([audits guide](https://developers.google.com/youtube/v3/guides/quota_and_compliance_audits), [developer policies](https://developers.google.com/youtube/terms/developer-policies)).

### Batching

- `videos.list` and `channels.list` take a comma-separated `id` list.
- Paged methods take `maxResults` up to 50 ([videos.list](https://developers.google.com/youtube/v3/docs/videos/list), [playlistItems.list](https://developers.google.com/youtube/v3/docs/playlistItems/list)).
- The documentation does not state a maximum number of IDs; 50 per call is the widely observed limit **(unverified)**.
- One call with 50 IDs and `part=snippet,contentDetails,statistics,status,topicDetails` costs 1 unit.

### ETags and conditional requests

- The API returns ETags and answers `If-None-Match` with **304 Not Modified**; Google presents this as a way to reduce latency and bandwidth ([getting started](https://developers.google.com/youtube/v3/getting-started)).
- The docs never say a 304 is free. The quota page says every request costs at least 1 unit.
- Third-party blogs claim 304s cost 0 **(unverified; assume 1 unit)**.
- The `fields` parameter trims payloads but not quota.

## 2. Captions and transcripts

- **`captions.list`** returns track metadata only: language, kind (ASR or standard), name. It needs OAuth with `youtube.force-ssl` or `youtubepartner` and costs **50 units** ([doc](https://developers.google.com/youtube/v3/docs/captions/list)).
- **`captions.download`** costs **200 units** and requires OAuth with `youtube.force-ssl` or `youtubepartner`. "This method requires the user to have permission to edit the video" ([doc](https://developers.google.com/youtube/v3/docs/captions/download)). In practice, the signed-in user's own videos or a channel they manage.
- **Cheap caption check:** `contentDetails.caption` in `videos.list` (1 unit) only says whether captions exist ([videos resource](https://developers.google.com/youtube/v3/docs/videos)).
- **Third-party transcripts are not officially available through any YouTube API.** The policies also forbid using "any technology other than YouTube API Services to access or retrieve API Data" and forbid scraping ([developer policies](https://developers.google.com/youtube/terms/developer-policies)). The player's timed-text endpoint and `yt-dlp` are therefore outside YouTube's terms.
- **The official Google alternative is the Gemini API.** It accepts a public YouTube URL as video input, so you can ask it for a transcript, a summary or quoted references ([video understanding](https://ai.google.dev/gemini-api/docs/video-understanding)).
  - Status: "Preview … available at no charge", with a free-tier limit of 8 hours of YouTube video a day.
  - Limits: public videos only, up to 10 videos per request on Gemini 2.5+.
  - Needs a Gemini API key, which is a separate Google product under its own terms.
  - A transcript produced this way is model output, not YouTube API Data. Timestamp accuracy is **unverified**.

## 3. History, subscriptions, likes, Watch Later, recommendations

- **Watch history (HL) and Watch Later (WL): gone.** The `watchHistory`/`watchLater` properties were deprecated on 2016-08-11. They always return the placeholders `HL`/`WL`, and "the watch history and watch later playlist IDs cannot be retrieved via the API". A 2020 note repeats that these lists "are, indeed, not accessible via the API" ([revision history](https://developers.google.com/youtube/v3/revision_history)).
- **Recommendations: gone.** `activities.list?home=true` returns an empty list since 2016, and `search.list?relatedToVideoId` was removed on 2023-08-07 ([revision history](https://developers.google.com/youtube/v3/revision_history)).
- **Subscriptions:** `subscriptions.list?mine=true` with `youtube.readonly`, 1 unit per page of 50 ([doc](https://developers.google.com/youtube/v3/docs/subscriptions/list)). This covers the "import subscriptions as candidate sources" need.
- **Liked videos:** `videos.list?myRating=like`, 1 unit per 50, 1,000 videos maximum ([doc](https://developers.google.com/youtube/v3/docs/videos/list)); or the `likes` playlist from `channels.contentDetails.relatedPlaylists`.
- **User playlists:** `playlists.list?mine=true`.
- **Data Portability API: watch history, official, but narrow.**
  - **Scopes:** `dataportability.myactivity.youtube` ("Move a copy of your YouTube activity") is **Restricted**. `dataportability.youtube.subscriptions` is Sensitive ([scopes](https://developers.google.com/data-portability/user-guide/scopes)).
  - **Format:** exported "My Activity" records carry `title` ("Watched…"), `titleUrl`, `subtitles` (the channel) and `time` ([schema](https://developers.google.com/data-portability/schema-reference/my_activity)).
  - **Availability:** only for accounts in the EU/EEA countries, Switzerland and the UK. Not for users under 18, Advanced Protection accounts, or managed accounts unless their admin allows it ([Google Account help](https://support.google.com/accounts/answer/14452558?hl=en), [overview](https://developers.google.com/data-portability/user-guide/overview)). A France-based owner qualifies; users outside Europe do not.
  - **Time-based access:** the user grants one-time, 30-day or 180-day access. An export can be re-run every 24 hours, and time filters ("since last export") are supported for My Activity ([time-based](https://developers.google.com/data-portability/user-guide/time-based), [time filter](https://developers.google.com/data-portability/user-guide/time-filter), [help](https://support.google.com/accounts/answer/14452558?hl=en)).
  - **Output:** each export is an asynchronous archive job that returns a signed download URL ([methods](https://developers.google.com/data-portability/user-guide/methods)).
  - **Requirements:** the project needs billing enabled ([setup](https://developers.google.com/data-portability/user-guide/setup)). The desktop OAuth flow is allowed, and token renewal only works "In production", because Testing tokens expire in 7 days ([configure OAuth](https://developers.google.com/data-portability/user-guide/configure-oauth)).
  - **Verification** covers brand, use case, demo video, then yearly re-verification. For restricted scopes it adds a CASA security assessment ([overview](https://developers.google.com/data-portability/user-guide/overview), [policy](https://developers.google.com/data-portability/policy)).
  - **Where CASA applies:** it is required when the app can reach restricted data "from or through a third-party server" ([restricted scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)). Whether a purely local app escapes the assessment is **unverified**.
  - **Unverified app:** fine for personal use, with the unverified-app screen and user cap.
- **Google Takeout:** available everywhere, manual. The user exports YouTube history (JSON or HTML) and the app imports the file. Google names it the fallback where the Data Portability API is unavailable ([help](https://support.google.com/accounts/answer/14452558?hl=en)). This is the user's own data file, not YouTube API Data, so the API storage rules arguably do not apply (legal interpretation, **unverified**).

## 4. YouTube Premium, ads and the embedded player

- **There is no API signal or Premium-only data.** No Data API resource or field mentions Premium ([videos](https://developers.google.com/youtube/v3/docs/videos), [channels](https://developers.google.com/youtube/v3/docs/channels)). An OAuth token for the Data API does not sign the player in.
- **What Premium needs:** ad-free playback applies "across all devices and platforms where you can sign in". For embeds, YouTube's troubleshooting says to make sure you are "not blocking YouTube cookies" when "watching a YouTube video embedded on a website" ([Premium benefits](https://support.google.com/youtube/answer/6308116?hl=en), [I see ads](https://support.google.com/youtube/answer/7437519?hl=en)). Premium in an embed therefore depends only on a youtube.com session cookie reaching the player.
- **Background play** is a mobile-app benefit only ([Premium benefits](https://support.google.com/youtube/answer/6308116?hl=en)). For API clients, background players are prohibited outright ([developer policies](https://developers.google.com/youtube/terms/developer-policies)).
- **Inside a Tauri/WKWebView app:**
  - **Signed out:** the embed plays with normal ads. The app must not block, modify or interfere with ads or the player ([developer policies](https://developers.google.com/youtube/terms/developer-policies)).
  - **Signed in, obstacle 1:** Google "might stop sign-ins from browsers that … are embedded in a different application" ([Google Account help](https://support.google.com/accounts/answer/7675428?hl=en)).
  - **Signed in, obstacle 2:** WKWebView has Intelligent Tracking Prevention on by default since macOS 11 ([WebKit](https://webkit.org/blog/10882/app-bound-domains/)), and WebKit blocks cross-site cookies by default ([WebKit](https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/)). An iframe on `tauri://localhost` is cross-site to youtube.com.
  - **A route that could work:** load `https://www.youtube.com/embed/VIDEO_ID` as the top-level page of a dedicated webview. The Required Minimum Functionality (RMF) policy documents this exact setup for apps ([RMF](https://developers.google.com/youtube/terms/required-minimum-functionality)), and it makes youtube.com cookies first-party.
  - **Status:** that route still needs a youtube.com login in that webview's data store. Whether Google accepts it and Premium applies is **unverified; needs a hands-on test**.
- **Player identity:** since 2025 the RMF requires every embedded player to send an HTTP `Referer`. In desktop WebViews the Referer is empty by default, and on macOS the app must set it to `https://<bundle-id>` ([RMF](https://developers.google.com/youtube/terms/required-minimum-functionality)). Without it, embeds fail with "Error 153" ([example](https://til.simonwillison.net/youtube/fixing-153-embed)). How to set it from a Tauri iframe loaded from `tauri://localhost` is **unverified**.
- **Other RMF rules:**
  - player at least 200×200 px;
  - no overlays over any part of the player;
  - autoplay only when more than half the player is visible;
  - use the OS WebView (WKWebView qualifies) ([RMF](https://developers.google.com/youtube/terms/required-minimum-functionality)).
- **Made for Kids:** API clients must look up the status of each video they embed (`status.madeForKids`) and turn off tracking for those videos ([developer policies](https://developers.google.com/youtube/terms/developer-policies)).
- **Related videos and end screens:**
  - Since 2018-09-25, "you will not be able to disable related videos"; `rel=0` only restricts them to the same channel ([player parameters](https://developers.google.com/youtube/player_parameters)).
  - `modestbranding`, `showinfo` and `autohide` are deprecated and have no effect.
  - Hiding the end-screen UI with CSS or overlays would break "must not modify, build upon, or block any portion or functionality of a YouTube player" and the overlay rule.
  - The legitimate lever is the IFrame API: listen for `onStateChange` = ENDED and replace or tear down the player in the app's own UI ([IFrame API](https://developers.google.com/youtube/iframe_api_reference)).
  - Whether tearing it down counts as "blocking functionality" is a gray area **(unverified)**. The "Permitted Feature Limitation" clause helps: a limitation that is a core aspect of the app is allowed if the app explains it and offers a way to the full feature, such as "Open on YouTube" ([developer policies](https://developers.google.com/youtube/terms/developer-policies)).

## 5. Sign-in for a native macOS app

### Google's rules

- **Recommended flow:** for macOS desktop apps, create a **Desktop app** OAuth client, open the **system browser**, and receive the code on a **loopback redirect** (`http://127.0.0.1:<random port>`). PKCE with S256 is supported and recommended ([OAuth for installed apps](https://developers.google.com/identity/protocols/oauth2/native-app)).
- **Embedded webviews are banned.** "A developer must not direct a Google OAuth 2.0 authorization request to an embedded user-agent" ([OAuth policies](https://developers.google.com/identity/protocols/oauth2/policies)), and WKWebView gets the `disallowed_useragent` error ([native-app errors](https://developers.google.com/identity/protocols/oauth2/native-app), [Google blog](https://developers.googleblog.com/upcoming-security-changes-to-googles-oauth-20-authorization-endpoint-in-embedded-webviews/)). The Tauri main webview cannot host Google sign-in.

### Native-feeling option: ASWebAuthenticationSession

- **Apple's view:** WebKit names ASWebAuthenticationSession as the right tool for web-based authentication ([WebKit](https://webkit.org/blog/10882/app-bound-domains/)).
- **Google's path:** Google's own Sign-In SDK for iOS and macOS uses an **iOS**-type OAuth client (bundle ID, optional App Check) with a reverse-client-ID custom scheme ([Get started for iOS and macOS](https://developers.google.com/identity/sign-in/ios/start-integrating), [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS)).
- **Contradiction in the docs:** the native-app guide still lists custom schemes for iOS clients, but also says "Custom URI schemes are no longer supported due to the risk of app impersonation", in a section about Android and Chrome ([native-app](https://developers.google.com/identity/protocols/oauth2/native-app)). Whether an iOS-type client with a custom scheme stays supported for a non-App-Store macOS app is **unverified**.
- **In Tauri:** a community plugin wraps ASWebAuthenticationSession for Tauri v2 ([tauri-plugin-auth-session](https://github.com/stippi/tauri-plugin-auth-session)). It is third-party, so maturity and supply chain need a check.
- **Safe default:** loopback plus system browser with a Desktop client. The upgrade is ASWebAuthenticationSession: it can also use a loopback `http` callback, a combination that is **unverified**.

### Token lifetime and publishing

- **Testing status:** an External app in "Testing" gets refresh tokens that **expire in 7 days** (unless it only asks for profile or email scopes) ([OAuth 2.0 overview](https://developers.google.com/identity/protocols/oauth2)).
- **Other ways a refresh token dies:** revocation, 6 months unused, and a cap of 100 refresh tokens per account per client.
- **"In production" but unverified:**
  - tokens do not expire after 7 days;
  - users see the unverified-app screen;
  - the app is capped at **100 new users** ([unverified apps](https://support.google.com/cloud/answer/7454865?hl=en)).
  - "Personal use" with a few known users is an exception to verification ([sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)).
  - This is the pragmatic mode for the owner and for bring-your-own-credentials users.
- **Is `youtube.readonly` sensitive?** Google says sensitivity is shown only in the Cloud Console ([scopes](https://developers.google.com/identity/protocols/oauth2/scopes)). Secondary sources and experience say **sensitive, not restricted** **(unverified in a primary doc; check the console)**.
- **Sensitive-scope verification:**
  - requirements: a verified domain, homepage and privacy policy, a justification per scope and a demo video on YouTube;
  - "typically takes 3-5 business days";
  - **no security assessment**, since CASA applies only to restricted scopes accessed through a server ([sensitive](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification), [restricted](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)).
  - The CASA assessment price is not published by Google **(unverified)**.
- **Separate YouTube obligations:** the YouTube API terms add their own: a privacy policy, a link to the YouTube ToS, and a link to Google's permissions page ([developer policies](https://developers.google.com/youtube/terms/developer-policies), [ToS](https://developers.google.com/youtube/terms/api-services-terms-of-service)).

### Client secrets in an open-source app

- **The secret is not secret:** installed apps "cannot keep secrets" ([native-app](https://developers.google.com/identity/protocols/oauth2/native-app)). The token endpoint now lists `client_secret` as **Optional** with PKCE (same page). Whether a Desktop client works without one is **unverified; test it**.
- **The policy blocks committing it anyway:** "you must not … embed your API Credentials in open source projects" ([developer policies](https://developers.google.com/youtube/terms/developer-policies)), where API Credentials are anything issued through the Cloud Console.
- **Options:**
  - Each user creates their own Cloud project, OAuth client and API key: the bring-your-own-credentials option, with a guided setup.
  - The owner injects credentials at build time into signed release binaries, never in the repo. They can still be extracted, and whether this is compliant is **unverified**.
  - A small backend holds the key. That breaks "local only" and makes the project an operator.
- **Token storage:** store refresh and access tokens in the macOS Keychain. The policies allow storing tokens "for as long as is necessary" for the consented purpose ([developer policies](https://developers.google.com/youtube/terms/developer-policies)). The app must never ask for or store YouTube passwords (same page).

## 6. Free mode without login

### With an API key only (no user login)

Everything public is available:

- channel resolution (`forHandle`);
- uploads via `playlistItems.list` on the UU playlist;
- full video details via `videos.list` and `batchGetStats`;
- topic categories;
- `search.list` (100 a day).

What is missing: transcripts, subscriptions, likes, history.

The key cannot ship in the open-source repo (section 5). Each user creates their own key in the Cloud Console, which takes a few minutes and is free. The free 10,000 units a day then belong to that user alone.

### With no key at all

- **Channel RSS feed:** `https://www.youtube.com/feeds/videos.xml?channel_id=UC…` **(tested)**.
  - **Semi-official:** Google documents this URL as the topic of its PubSubHubbub push service ([push notifications](https://developers.google.com/youtube/v3/guides/push_notifications)), but the Atom format itself has no reference page.
  - **Size:** exactly **15** entries, the most recent uploads **(tested)**.
  - **Each entry:** video id, channel id, title, watch link, author, `published`, `updated`, `media:description` (full description), `media:thumbnail` (hqdefault 480×360), `media:statistics views` and `media:starRating` (a like count).
  - **Missing:** duration, tags, category, live status.
  - **Shorts:** they are included and recognizable, because their link is `/shorts/ID` instead of `/watch?v=` **(tested)**.
  - **Caching:** the server sends `cache-control: public, max-age=900` (15 min) and no ETag or Last-Modified; `If-Modified-Since` returns 200 **(tested)**. Polling faster than every 15 minutes is useless.
  - **Uploads playlists:** `?playlist_id=UULF…` returns only long-form uploads and `UUSH…` only Shorts **(tested; undocumented, may change)**.
- **oEmbed:** `https://www.youtube.com/oembed?url=…&format=json` returns title, author name and URL, thumbnail and embed HTML **(tested; not in the YouTube developer docs)**.
- **Thumbnails:** `i.ytimg.com/vi/ID/{hqdefault,maxresdefault}.jpg` load directly **(tested)**.
- **Embeds:** the IFrame player needs no key or auth ([developer policies](https://developers.google.com/youtube/terms/developer-policies)).
- **Push notifications (PubSubHubbub/WebSub):** free, but they need a public callback server, which does not fit a local app ([push notifications](https://developers.google.com/youtube/v3/guides/push_notifications)).

### Enough for the demo

The keyless free mode covers the demo. Add sources by channel URL: resolve the handle to a channel ID from the channel page, or ask the user for the ID, since resolving a handle officially needs the API. Build the feed from RSS, get Shorts off for free with the UULF feed, play with embeds, and get durations only when a key is present.

Whether RSS data counts as "API Data" under the YouTube terms is **unverified**. The conservative reading applies the same 30-day rule.

## 7. Policy constraints that touch focustube

Sources: [Developer Policies](https://developers.google.com/youtube/terms/developer-policies), updated 2026-09-14; [API ToS](https://developers.google.com/youtube/terms/api-services-terms-of-service); [RMF](https://developers.google.com/youtube/terms/required-minimum-functionality).

The policies apply to the API client wherever it stores data, a local SQLite database included.

- **30-day storage (III.E.4).**
  - "Non-Authorized Data" (fetched with a key, no user credentials) may be stored "temporarily", in "limited amounts", "not longer than 30 calendar days", after which the client "must either delete or refresh" it.
  - Statistics fetched without authorization (views, likes, subscriber counts) must not be kept more than 30 days.
  - "Authorized Data" (fetched with OAuth: subscriptions, likes) also has a 30-day limit, and the client must re-check the authorization.
  - Clients should reflect metadata changes "as quickly as possible" and show the latest data; historical data may be shown if presented "accurately in context of time".
  - **Consequence:** every API-sourced row in SQLite needs a `fetched_at` and a job that refreshes (1 unit per 50 videos) or deletes it after 30 days.
- **Deletion.**
  - The app must offer a "delete stored data" control and honor it within 7 days.
  - It must delete Authorized Data within 7 days of a revocation, and within 30 days for tokens that can no longer be refreshed.
  - The privacy policy must link to `https://security.google.com/settings/security/permissions`.
- **Derived data (highest risk).**
  - The rule: "Your API Clients must not … (ii) access or use API Data to create new or derived data or metrics."
  - The policy's own example forbids "a score that factors in likes, total views, or any other API Data".
  - Non-YouTube data shown next to API data must be disclosed as the app's own.
  - The 2026 "derived metrics" allowance (section III.L) covers only audited analytics use cases ([derived metrics policy](https://developers.google.com/youtube/terms/derived-metrics-policy)).
  - **What is at risk:** [preference learning](../features/preference-learning.md) or [recommendations](../features/recommendations.md) that score videos from views, likes, tags or topics, and AI summaries of titles and descriptions.
  - **What is safe:** learning based on the user's own explicit feedback, clearly labeled as the app's own. Summaries of transcripts obtained outside the YouTube API (the Gemini API or the user's own notes) are not API Data, though the Gemini output is covered by its own terms.
  - How strictly YouTube applies this to a single-user local app is **unverified**. It would come up in any quota audit.
- **Player and ads.** The app must not:
  - "modify, interfere with, replace, or block advertisements";
  - "modify, build upon, or block any portion or functionality of a YouTube player";
  - put overlays on the player;
  - build background players;
  - download, cache or offer offline playback of audiovisual content.
- **Not replicating YouTube.** Clients "must not mimic or replicate YouTube's core user experiences … unless they add significant independent value". Example: "must not recreate the browse experience … without adding significant independent value". Filtering, per-theme organization, analysis and notes are the independent value focustube needs to be able to show.
- **Feature limitation.** Hiding YouTube features, such as Shorts or the next video, is allowed if it is a "core aspect" of the app. The app must explain the limitation is its own choice, not YouTube's, and offer a path to the full feature.
- **Aggregation.** Do not aggregate API data to gain insights into YouTube's usage or business. Per-user local use is fine.
- **Branding.** Screens that show YouTube content must attribute YouTube per the [branding guidelines](https://developers.google.com/youtube/terms/branding-guidelines).
- **Scraping.** Scraping YouTube is forbidden, as is using "any technology other than YouTube API Services to access or retrieve API Data".
- **Updates.** Installed clients "must be capable of being remotely updated", which the Tauri updater covers.
- **Credentials.** No API credentials in open-source repos (section 5).

## 8. Recommended quota-minimizing strategy

1. **Discovery through RSS (0 units).**
   - Poll each followed channel's feed, preferably the UULF variant, at most every 15 minutes; hourly is enough.
   - Keep a set of known video IDs and diff each fetch against it.
   - Fall back to `playlistItems.list` on the UU playlist (1 unit) when a feed fails or when backfilling beyond 15 entries.
2. **Details in batches.** Queue new IDs and call `videos.list?id=<≤50 ids>&part=snippet,contentDetails,status,topicDetails` once per refresh cycle, for 1 unit per 50 new videos. Add `statistics` only if it is shown in the UI. `status.madeForKids` is needed for the Made for Kids rule.
3. **Channels.** Call `channels.list?id=<≤50>&part=snippet,contentDetails` when a source is added and on the 30-day refresh.
4. **The 30-day refresh obligation.** Each day, re-fetch the videos whose `fetched_at` is older than 29 days and that are still in the feed or referenced by notes, batched by 50. Delete API fields for the rest, but keep the user's own notes and feedback keyed by video ID.
5. **ETags.** Send `If-None-Match` on refreshes to save bandwidth. Budget 1 unit per call anyway (section 1).
6. **OAuth-only data on demand.** Import subscriptions once, then re-sync weekly: 1 unit per 50. Pull likes the same way. Never poll them.
7. **Search.** Use `search.list` only for an explicit "find a channel" action, within its own bucket of 100 calls a day.
8. **Accounting.** Count units per call in SQLite, stop at a user-set ceiling, and report `quotaExceeded` (403) in the UI ([errors](https://developers.google.com/youtube/v3/docs/errors)).

### Daily cost for 50 followed channels

Assumptions: about 1 new video per channel per day, and about 1,500 stored videos over 30 days.

| Item | RSS-first | API-only (hourly `playlistItems`) |
| --- | --- | --- |
| Discovery | 0 | 50 × 24 = 1,200 |
| New-video details (≈50 a day) | 1–2 | 1–2 |
| 30-day refresh (1,500 ÷ 30 = 50 a day) | 1 | 1 |
| Channel refresh | 0–1 | 0–1 |
| Subscriptions and likes sync (weekly) | < 1 | < 1 |
| **Total units a day** | **≈ 3–5** | **≈ 1,205** (≈ 55 if polled twice a day) |

**Bring-your-own key:** even the API-only mode fits in 10,000 units.

**Shared project:** if the project ever ran one key for all users through a backend, RSS-first allows thousands of users per 10,000 units, while hourly API polling allows about 8.

## Data points at a glance

| Data point | Source | Auth needed | Quota cost | Storable? |
| --- | --- | --- | --- | --- |
| New uploads (15 latest), title, description, published, thumbnail, views | Channel RSS feed | None | 0 | Unclear whether RSS counts as API Data; treat as 30 days max |
| Shorts or long-form split | RSS link (`/shorts/`) or UULF/UUSH feed | None | 0 | Same as above (undocumented) |
| Uploads list (full history, paged) | `playlistItems.list` (UU playlist) | API key | 1 per 50 | ≤ 30 days, then refresh or delete |
| Title, description, tags, category, thumbnails | `videos.list` `snippet` | API key | 1 per ≤50 IDs | ≤ 30 days, then refresh or delete |
| Duration, definition, captions yes or no, region restriction | `videos.list` `contentDetails` | API key | same call | ≤ 30 days |
| Views, likes, comments | `videos.list` `statistics` or `videos.batchGetStats` | API key | 1 (batchGetStats has its own bucket) | ≤ 30 days (unauthorized statistics) |
| Topic categories (Wikipedia URLs) | `videos.list` `topicDetails` | API key | same call | ≤ 30 days |
| Live or upcoming status and times | `snippet.liveBroadcastContent`, `liveStreamingDetails` | API key | same call | ≤ 30 days |
| Made for Kids, embeddable | `videos.list` `status` | API key | same call | ≤ 30 days; must be checked before embedding |
| Chapters | Parsed from description | API key | same call | Derived from API data (gray area) |
| Channel info, uploads playlist ID | `channels.list` (`id` or `forHandle`) | API key | 1 per ≤50 | ≤ 30 days |
| Keyword search | `search.list` | API key | 1, in a 100-a-day bucket | ≤ 30 days |
| Caption track list | `captions.list` | OAuth `youtube.force-ssl` | 50 | ≤ 30 days |
| Caption text | `captions.download` | OAuth, and edit rights on the video | 200 | Own videos only |
| Transcript or summary of any public video | Gemini API with a YouTube URL | Gemini API key | Gemini pricing (free preview) | Not YouTube API Data (Gemini terms apply) |
| Subscriptions | `subscriptions.list?mine=true` | OAuth `youtube.readonly` | 1 per 50 | Authorized Data, ≤ 30 days, delete on revoke |
| Liked videos | `videos.list?myRating=like` or the LL playlist | OAuth `youtube.readonly` | 1 per 50 (1,000 max) | Authorized Data, ≤ 30 days |
| Own playlists | `playlists.list?mine=true` | OAuth `youtube.readonly` | 1 per 50 | Authorized Data, ≤ 30 days |
| Watch history | Not in the Data API; Data Portability API `myactivity.youtube` | OAuth, restricted scope, verification | Not YouTube quota; Cloud billing required | Governed by Google's user-data policy, not the YouTube 30-day rule (unverified) |
| Watch history (manual) | Google Takeout file | User exports it | 0 | The user's own file (unverified interpretation) |
| Watch Later | Not available | n/a | n/a | n/a |
| Recommendations or related videos | Not available (`home` and `relatedToVideoId` removed) | n/a | n/a | n/a |
| Premium status | Not available | n/a | n/a | n/a |
| Title, author, embed HTML | oEmbed | None | 0 | Undocumented; treat like API data |
| Playback | IFrame player | None (Referer required) | 0 | Caching audiovisual content forbidden |

## Open questions

- **Premium in Tauri:** does ad-free playback work when `youtube.com/embed/ID` loads top-level in a WKWebView where the user signed in to youtube.com, or does Google refuse sign-in in that embedded browser? This needs a prototype.
- **Referer from Tauri:** how do we send `Referer: https://<bundle-id>` for an iframe loaded from `tauri://localhost`? The candidates are a top-level embed webview with custom request headers in wry, or a meta referrer policy. Error 153 is what happens when the Referer is missing.
- **Quota cost of a 304:** does a conditional `If-None-Match` request that returns 304 still cost 1 unit? Check the Cloud Console quota metrics.
- **ID cap:** is 50 IDs per `videos.list` a hard limit? It is not documented.
- **Client secret:** does a Desktop OAuth client complete the PKCE token exchange without `client_secret`? And is an iOS-type client with ASWebAuthenticationSession accepted for a macOS app distributed outside the App Store?
- **Scope class:** confirm in the Cloud Console that `youtube.readonly` is "sensitive", not "restricted".
- **Credentials policy:** do build-time-injected credentials in signed binaries of an open-source app satisfy "must not embed your API Credentials in open source projects"? Or is bring-your-own the only compliant option? This could be asked through the YouTube API compliance contact.
- **Derived data:** how does YouTube read "must not … create new or derived data" for local preference scoring and AI summaries of descriptions? This matters before any quota audit.
- **RSS status:** do RSS and oEmbed data fall under the YouTube API Services terms (30-day rule)? They are not listed as API services, but they are YouTube data.
- **CASA:** does the Data Portability API's restricted `myactivity.youtube` scope require a CASA assessment for an app with no server? And what do Google's approved assessors charge today? The price is not published.
