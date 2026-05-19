# LLMUIDownloads Overview

`LLMUIDownloads` provides optional backend-agnostic model lifecycle UI.

The view model can consume any `ModelLifecycleService` and maps install events into presentation state without owning storage,
backend, or downloader logic.

The module exposes both a full downloads list and smaller reusable row cards so host apps can place install controls directly
next to their model catalog or selection surfaces. Cards keep the default view focused on name, status, backend, family, size,
icon actions, and line progress without leaking lifecycle logic into views.

`ModelCatalogCardView` provides the compact catalog-row treatment used by the example app as reusable package UI. It accepts
backend-neutral descriptor, status, install state, progress, selection, install, cancel, delete, and details actions without owning
model lifecycle or selection policy.
`StorageUsageView` provides a compact reusable summary for downloaded model count, installed bytes, partial bytes, and optional
disk free/capacity usage.
