# LLMSessions Public API

Public API includes session coordination and transcript value types.

`SessionCoordinator` creates sessions, loads snapshots from an optional `SessionStore`, caches loaded snapshots, and persists appended messages through the store when present. `SessionTruncationPolicy` builds a most-recent-message window and allows an empty window when `maxMessages` is zero.
