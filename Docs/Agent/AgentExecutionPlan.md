# Agent Execution Plan

## Current Status

The initial architecture pass is hardened. Package targets, module docs, ADRs, core contracts, coordination modules, orchestration, lifecycle/storage, backend skeletons, UI skeletons, architecture boundary tests, and focused runtime tests are present and verified.

## Completed

1. Scaffold folders and docs.
2. Implement `LLMCore`.
3. Implement `LLMProtocols`.
4. Implement coordination modules.
5. Implement `LLMOrchestrator`.
6. Implement backend skeletons.
7. Implement UI skeletons.
8. Add focused tests and verify the package.
9. Harden boundary, routing/fallback, lifecycle/storage, remote mapping, session, prompting, tools, backend skeleton, and UI view-model behavior.
10. Synchronize module docs with implemented public behavior.

## Active

1. Keep tests and docs synchronized as new behavior is introduced.
2. Continue to expand tests only around stable public invariants and routing behavior.

## Later

1. Add real provider integrations only inside backend targets.
2. Expand lifecycle download/warmup/eviction policies without mixing them into inference orchestration.
3. Add richer UI previews or examples once public services stabilize.
