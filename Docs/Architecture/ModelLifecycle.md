# Model Lifecycle

Model lifecycle is separate from inference. It owns discovery, download, verification, compilation, warmup, eviction, and installed-state reporting. UI reads lifecycle state through public services and never mutates storage directly.

Interrupted installs are lifecycle-owned. By default, cancellation preserves verified artifacts and downloader resume cache for retry; eager cleanup must be selected explicitly through lifecycle policy.
