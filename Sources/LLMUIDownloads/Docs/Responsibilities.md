# LLMUIDownloads Responsibilities

Owns model download/install presentation. It consumes lifecycle services and does not touch storage or backend SDKs directly.
Provides both aggregate downloads screens and embeddable single-model progress components for demo or app-specific catalogs.
When lifecycle progress is only heuristic, this module must present it as approximate rather than pretending it is byte-accurate.
