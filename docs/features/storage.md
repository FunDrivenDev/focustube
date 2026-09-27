# Storage

Everything the app learns and every setting stays on your Mac, in a SQLite database in the app's data folder (`~/Library/Application Support/dev.fundrivendev.focustube`).

## What it holds

- [Themes](themes.md), [sources](sources.md) and hard rules.
- Videos and their metadata, transcripts, [summaries and learnings](analysis.md), [references](references.md) and [notes](notes.md).
- [Learned preferences](preference-learning.md) and the feedback they come from.
- The API cache and the quota count.
- Settings, which the template keeps today in a JSON file.

Tokens are not in the database: they live in the Keychain (see [Accounts](accounts.md)).

## Open questions

- Which crate: `rusqlite` or `sqlx`, and how are migrations run?
- How do undo and redo (`History` in `src-tauri/src/model.rs`) map onto database writes?
