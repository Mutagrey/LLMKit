# LLMPrompting Public API

Public API includes prompt templates, identifiers, versions, and assembly snapshots.

`PromptAssembler` joins fragments with newlines, substitutes known `{{variable}}` placeholders, preserves unknown placeholders, and allows empty templates. `PromptRegistry` replaces templates by ID and returns `nil` for unknown IDs.
