# LLMUIModels Overview

`LLMUIModels` provides optional backend-agnostic model lifecycle UI.

The view model can consume any `ModelLifecycleService` and maps install events into presentation state without owning storage,
backend, or downloader logic.

The module exposes one reusable `ModelListView` for model catalog, selection, install controls, delete actions, and optional
storage summary. Rows keep the default view focused on name, status, backend, family, size, icon actions, and line progress
without leaking lifecycle logic into views.

`ModelRowView` accepts backend-neutral descriptor, status, install state, progress, selection, install, cancel, delete, and
details actions without owning model lifecycle or selection policy.
`StorageUsageView` provides a compact reusable summary for downloaded model count, installed bytes, partial bytes, and optional
disk free/capacity usage through `ModelStorageSummary`, using the shared `LLMUIStorage` stacked storage bar.
