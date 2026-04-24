# LLMUIDownloads Overview

`LLMUIDownloads` provides optional backend-agnostic model lifecycle UI.

The view model can consume any `ModelLifecycleService` and maps install events into presentation state without owning storage,
backend, or downloader logic.

The module exposes both a full downloads list and smaller reusable download cards so host apps can place install controls directly
next to their model catalog or selection surfaces. The full list now groups installed models separately from installable catalog
entries, while cards expose model family, provider, revision, and device requirements without leaking lifecycle logic into views.
