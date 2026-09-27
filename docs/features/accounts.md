# Accounts

The app works without an account. Connecting a Google account, and optionally YouTube Premium, adds your subscriptions, your history and ad-free playback.

## What it does

- Sign in with Google through OAuth, in the browser; the tokens go in the macOS Keychain.
- Import your subscriptions as candidate [sources](sources.md).
- Use your history for [preference learning](preference-learning.md) and [recommendations](recommendations.md).
- With YouTube Premium, play without ads.
- Sign out and forget every token from Settings.

## Open questions

- There is no Premium API: does Premium only apply when playback happens in a signed-in YouTube player?
- Which OAuth scopes are enough (`youtube.readonly`), and does the app need Google's verification to ship publicly?
