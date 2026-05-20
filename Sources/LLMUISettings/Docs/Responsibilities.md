# LLMUISettings Responsibilities

Owns SwiftUI presentation for `LLMRuntimeSettings`, section visibility, settings navigation helpers, formatting helpers, and
host action hooks.

It does not choose models, download artifacts, apply runtime changes directly, inspect storage paths, or import backend
modules.
Storage cleanup controls invoke host-provided closures only; deletion and persistence remain owned by lifecycle and storage
services. The UI must ask for confirmation before invoking destructive cleanup closures.
