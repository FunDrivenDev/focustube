# Preference learning

The feed learns what you want over time, from your [feedback](feedback.md), what you watch and skip, and your YouTube history when you are [connected](accounts.md). What it learned stays local and visible.

## What it does

- Scores each video against your preferences to rank the feed.
- Shows why a video is in the feed ("from a source you follow", "you watched three talks like it").
- Lets you see, change and reset what it learned.

## Open questions

- Which model: simple weights per source and keyword, or embeddings of titles and transcripts?
- The YouTube Data API does not give the watch history; is a Google Takeout import enough?

## Research

See [the constraints](../research/README.md) that YouTube sets on this feature.
