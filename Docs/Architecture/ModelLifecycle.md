# Model Lifecycle

Model lifecycle is separate from inference. It owns discovery, download, verification, compilation, warmup, eviction, and installed-state reporting. UI reads lifecycle state through public services and never mutates storage directly.
