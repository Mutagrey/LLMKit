# LLMDeviceProfiling Overview

`LLMDeviceProfiling` exposes backend-neutral device and runtime signals for routing inputs.

`DeviceProfileCollector` snapshots stable hardware facts such as operating system version, physical memory,
processor count, and available process memory where Apple exposes that signal. `RuntimeConstraintsCollector`
captures ephemeral execution constraints such as low power mode preference and currently available free disk
budget for the active volume.

`LocalRuntimeMemoryGuard` gives orchestration a backend-neutral preflight for local model loading. It compares an
estimated resident model/context/working set against process-available memory plus a safety reserve, without owning
lifecycle or backend runtime state. Callers decide the resident-memory estimate, so mmap-backed artifacts do not need
to be modeled as fully resident files.
