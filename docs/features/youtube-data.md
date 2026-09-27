# YouTube data

The app fetches what it needs from YouTube itself, as plain code: no agent required.

## What it does

- Gets an API key or OAuth token, and keeps it in the Keychain.
- Fetches titles, descriptions, durations, channels and publication dates for your sources.
- Fetches transcripts for [analysis](analysis.md).
- Respects the rate limits and the daily quota: it counts units, caches responses, backs off, and says in the app when the quota is spent.
- Refreshes when the app starts and on demand, never in a loop.

## Open questions

- The Data API's quota is 10,000 units a day; listing uploads costs 1 unit, a search 100. Is the channel's RSS feed a free way to find new videos?
- The Data API only downloads captions of your own videos: where do other transcripts come from (the player's timed text, a library such as `yt-dlp`), and within which terms of service?

## Research

See [the constraints](../research/README.md) that YouTube sets on this feature.
