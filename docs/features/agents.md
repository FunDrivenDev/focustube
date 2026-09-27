# Agents

The app can be connected to Claude Code or another agent, but it never needs one: every step also runs as plain code.

## What it does

- Hands an agent the heavy tasks when one is set: [analysis](analysis.md), [reference](references.md) lookups, [recommendations](recommendations.md).
- Exposes the app's data to the agent, read-only by default, for example through an MCP server.
- Falls back to plain code, or skips the task and says so, when no agent is set.

## Open questions

- Which direction: the app calls the agent, or the agent drives the app through MCP, or both?
- Which agents besides Claude Code, and how is one chosen in Settings?
