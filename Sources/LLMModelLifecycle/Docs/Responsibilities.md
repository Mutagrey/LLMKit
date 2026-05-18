# LLMModelLifecycle Responsibilities

Owns lifecycle state transitions, model catalog data, signed remote catalog fallback, declared artifact downloads,
artifact integrity checks, resumable download retry policy, disk-space preflight, interrupted-download cleanup/resume policy,
remote manifest trust policy, and installed record persistence. Cancellation policy covers both verified artifacts and
downloader resume cache. It does not execute prompts, own session history, import backend runtimes, or render progress UI.
