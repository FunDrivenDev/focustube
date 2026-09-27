# Analysis

When the app starts, or when you choose "analyze" on a video, it reads the transcript, summarizes it and extracts learnings. It serves two purposes: to help you decide whether to watch the video, and to surface knowledge worth keeping or exploring further.

## What it does

- Summarizes a video in a few lines, shown in the [feed](feed.md).
- Analyzes new videos on launch, within a budget you set, or one video on demand.
- Stores every result locally, so a video is analyzed once.

## Learnings

- Extracts the nuggets of a video: claims, techniques, definitions, each with its timestamp.
- Lets you keep, discard or explore a learning further; kept learnings join your [notes](notes.md).
- Finds the [references](references.md) the video quotes.

## Open questions

- Who does the summarizing: a local model, an API such as Claude's, or an [agent](agents.md)? Each has a cost and a privacy trade-off.
- How long is a summary, and is it per theme (what matters to this theme) or generic?
