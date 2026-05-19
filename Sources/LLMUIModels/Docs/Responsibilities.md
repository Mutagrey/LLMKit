# LLMUIModels Responsibilities

Owns model download/install presentation. It consumes lifecycle services and does not touch storage or backend SDKs directly.
Provides one unified model list plus embeddable row, detail, progress, and storage-summary components for demo or app-specific
catalogs. When lifecycle progress is only heuristic, this module must avoid presenting it as byte-accurate.
