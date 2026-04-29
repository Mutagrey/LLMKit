# LLMExampleUI Dependency Rules

`LLMExampleUI` may import UI modules, orchestration, lifecycle, protocols, core types, session and prompt coordination
modules, storage-backed demo persistence helpers, and concrete backend adapters because it is a demo composition target.

This target must not move backend imports into `LLMUIChat` or `LLMUIDownloads`.

It must not implement transport, persistence, inference routing, or model download logic directly.
