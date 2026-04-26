# LLMModelLifecycle Responsibilities

Owns lifecycle state transitions, model catalog data, signed remote catalog fallback, declared artifact downloads,
artifact integrity checks, interrupted-download cleanup/resume policy, and installed record persistence. It does not execute prompts, own session history,
import backend runtimes, or render progress UI.
