# LLMUIModels Public API

Public API includes a unified model list, install progress presentation, detail view, formatting helpers, reusable storage
summary, and a lifecycle-backed downloads view model.

`ModelListView` renders model descriptors with optional `ModelStorageSummary`, search, backend/state filters, sorting, grouping,
detail presentation, selection, install, pause/resume, and delete actions.
`ModelRowView` renders a compact model row/card for model pickers and example catalogs. Hosts provide generic status,
availability, selection, install, cancel, delete, and details actions; the view does not choose models, route requests, or touch storage.
`ModelDetailView` renders backend-neutral model details for list sheets. `ModelFormatting` provides shared backend, byte-count,
and capability titles so apps do not need duplicate model-display formatting.
`ModelStorageSummary` is the view input for downloaded count, installed bytes, partial bytes, and optional disk free/capacity.
`StorageUsageView` renders that summary with a compact usage bar.
`ModelInstallProgressView` renders install state as a compact line-style progress component suitable for lists and detail sections.
Progress presentation is normalized defensively so percent-shaped external inputs do not render inflated percentages.

`ModelDownloadsViewModel.install(_:)` consumes model install events, tracks in-flight installs by model ID, records thrown install
errors as short presentation-safe messages, updates install state by model ID, and stores richer progress detail when the
lifecycle layer exposes it. Raw `NSError` payloads, resume data, and presigned download URLs are not surfaced to views.
`refresh()` loads installed records and reconciles tracked descriptor states through `ModelLifecycleService` when one is provided.
When the lifecycle service also conforms to `ModelLifecycleMaintenanceService`, the view model exposes installed storage totals
and delete/clear actions without owning file paths or persistence details. Storage totals include configured descriptors with
partial artifacts, so failed downloads can still expose cleanup affordances.
`ModelDownloadsViewModel.beginInstall(_:)` and `cancelInstall(_:)` let hosts drive install lifecycle from UI without
holding task handles in view code. Cancel waits for lifecycle cancellation handling before allowing another install for the
same model; under the default lifecycle policy, cancellation surfaces as `.paused(progress:)` while preserving hidden resume
data so retry can continue the interrupted transfer without exposing resume files to UI.
`clearPartialArtifacts()` and `clearInstalledModels()` provide host-triggered bulk cleanup affordances while still routing
all deletion through `ModelLifecycleMaintenanceService`.
