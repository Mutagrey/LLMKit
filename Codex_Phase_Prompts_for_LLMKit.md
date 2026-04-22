# Codex Phase Prompts for LLMKit

Use these prompts in order.

For best results:
- keep the repository open with `AGENTS.md` in the root
- place architecture files under `Docs/Architecture/`
- run one phase at a time
- do not ask Codex to build the whole SDK in one pass

---

## Recommended model selection

- Phase 0 planning: **GPT-5.4 xhigh**
- Scaffold: **GPT-5.4 high**
- Core and protocols: **GPT-5.4 high** or **GPT-5.3-Codex medium**
- Orchestrator and lifecycle: **GPT-5.4 high**
- Backends: **GPT-5.4 high**
- Small patches and local refactors: **GPT-5.3-Codex medium**

If a task is architecture-sensitive, prefer GPT-5.4.

---

## Phase 0 — planning only

```text
Read these files first and treat them as the source of truth:

- AGENTS.md
- Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md
- Docs/Architecture/LLMKit_Package_Scaffold_and_Target_Graph.md
- Docs/Architecture/LLMKit_Module_File_Map.md
- Docs/Architecture/LLMKit_Agent_Execution_Prompt.md
- Package.swift

Task:
Do not implement yet.
First produce a concrete execution plan for scaffolding and implementing this Swift package.

Requirements:
- preserve strict layer boundaries
- preserve target dependency graph
- no duplicate domain types
- no external dependencies unless justified in ADR
- create per-module Docs files from the start
- keep public API minimal
- use modern Swift concurrency and latest Apple SDK practices

Output:
1. ordered execution plan
2. proposed first commit scope
3. risks or ambiguities
4. any suggested refinements to the package graph

Do not write code yet.
```

---

## Phase 1 — scaffold only

```text
Read first:
- AGENTS.md
- Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md
- Docs/Architecture/LLMKit_Package_Scaffold_and_Target_Graph.md
- Docs/Architecture/LLMKit_Module_File_Map.md
- Package.swift

Proceed with phase 1 only.

Create the initial package scaffold exactly according to the architecture docs:
- Package.swift
- Sources tree
- Tests tree
- Docs tree
- ADR stubs
- per-module Docs folders and placeholder files

Rules:
- structural scaffold only
- near-zero implementation logic
- do not add speculative abstractions
- do not add third-party dependencies
- do not collapse modules
- do not invent alternative architecture

At the end, provide:
- created files tree
- any deviations from the blueprint
- unresolved issues only if they block correctness
```

---

## Phase 2 — implement LLMCore only

```text
Read first:
- AGENTS.md
- Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md
- Docs/Architecture/LLMKit_Module_File_Map.md
- module docs for Sources/LLMCore/Docs/

Proceed with phase 2: implement LLMCore only.

Scope:
- create the domain types defined in the file map for LLMCore
- keep all types backend-agnostic
- keep imports minimal
- do not implement orchestration
- do not add provider-specific fields
- add focused tests for public invariants

Constraints:
- one primary responsibility per file
- keep public API intentional
- prefer value types
- avoid convenience logic in LLMCore

Deliver:
- concise summary of created types
- explanation of any type merges or simplifications
- test coverage summary
```

---

## Phase 3 — implement LLMProtocols only

```text
Read first:
- AGENTS.md
- Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md
- Docs/Architecture/LLMKit_Module_File_Map.md
- Sources/LLMProtocols/Docs/

Proceed with phase 3: implement LLMProtocols only.

Rules:
- protocols must align with LLMCore
- do not add backend-specific leakage
- keep service contracts small and stable
- prefer protocol names that describe responsibilities
- add narrow protocol tests or compile-level validation where appropriate

Do not:
- implement backend adapters
- implement orchestrator behavior
- add UI-facing state here

Report:
- files created or changed
- protocol groups added
- any contract simplifications
- any mismatches noticed between docs and code
```

---

## Phase 4 — implement supporting coordination modules

```text
Read first:
- AGENTS.md
- Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md
- Docs/Architecture/LLMKit_Module_File_Map.md
- module docs for:
  - LLMSessions
  - LLMPrompting
  - LLMTools
  - LLMSafety
  - LLMObservability
  - LLMStorage
  - LLMDeviceProfiling
  - LLMModelLifecycle

Proceed with phase 4 only.

Implement the supporting coordination modules, but keep each module strictly within its responsibility.

Key rules:
- no backend SDK imports
- no orchestration policy leakage into storage or sessions
- no prompt execution in lifecycle
- no transport logic outside LLMNetworking / remote backend
- keep each module small and testable

Done means:
- module files exist and compile
- per-module docs are updated
- focused tests are added for key invariants
- architecture boundaries remain intact

Report:
- modules completed
- notable design choices
- risks or deferred items per module
```

---

## Phase 5 — implement LLMOrchestrator only

```text
Read first:
- AGENTS.md
- Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md
- Docs/Architecture/LLMKit_Package_Scaffold_and_Target_Graph.md
- Docs/Architecture/LLMKit_Module_File_Map.md
- Sources/LLMOrchestrator/Docs/

Proceed with phase 5: implement LLMOrchestrator only.

Scope:
- create the app-facing container and service composition layer
- implement routing, planning, and fallback coordination
- keep pipelines composable
- preserve a compact public API

Rules:
- do not pull backend-specific DTOs into orchestrator
- do not implement UI here
- do not create a giant god object
- prefer smaller coordinator types and pipelines
- keep factory/container construction explicit

Deliver:
- list of orchestrator types added
- explanation of request flow
- how routing and fallback are modeled
- remaining integration points for backend modules
```

---

## Phase 6 — implement backend adapters

```text
Read first:
- AGENTS.md
- Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md
- Docs/Architecture/LLMKit_Module_File_Map.md
- module docs for backend targets

Proceed with phase 6 only.

Implement backend adapters in this order:
1. LLMBackendFoundationModels
2. LLMBackendRemote
3. LLMBackendCoreML
4. LLMBackendMLX

Rules:
- isolate SDK-specific imports in backend modules only
- keep request/response mapping explicit
- do not leak provider-specific DTOs upward
- document maturity and limitations, especially for MLX
- keep support matrices explicit where needed

Add focused tests for:
- request mapping
- response mapping
- error mapping
- availability behavior where practical

Report:
- backend modules completed
- unsupported or deferred capabilities
- any platform constraints that affect integration
```

---

## Phase 7 — implement UI modules

```text
Read first:
- AGENTS.md
- Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md
- Docs/Architecture/LLMKit_Module_File_Map.md
- Sources/LLMUIChat/Docs/
- Sources/LLMUIDownloads/Docs/

Proceed with phase 7 only.

Implement reusable SwiftUI UI modules:
- LLMUIChat
- LLMUIDownloads

Rules:
- UI must consume public services only
- no backend-specific logic in UI
- no persistence ownership in views
- keep view models presentation-focused
- model streaming state explicitly
- keep theming and rendering composable

Deliver:
- created UI types
- state ownership summary
- integration expectations with host apps
- any intentionally deferred UI polish items
```

---

## Phase 8 — tests, examples, polish

```text
Read first:
- AGENTS.md
- all relevant module docs

Proceed with phase 8 only.

Add:
- missing focused tests
- example app or demo target if appropriate
- fixture data where useful
- documentation polish
- validation scripts only if they clearly help maintain architecture boundaries

Rules:
- do not rewrite stable architecture without strong reason
- keep examples lightweight
- avoid bloated infra
- improve clarity, not just surface area

Deliver:
- added tests
- examples or fixtures added
- docs improved
- final architecture health summary
```

---

## Narrow patch prompt template

Use this for any smaller follow-up task.

```text
Read first:
- AGENTS.md
- relevant module docs only

Task:
[describe one narrow task]

Constraints:
- stay within the target module(s)
- do not widen scope
- do not add unrelated refactors
- preserve architecture boundaries
- add or update tests if public behavior changes

Report:
- files changed
- exact behavior added or modified
- any architectural concerns noticed
```

---

## Practical usage order

1. Run Phase 0 in plan mode.
2. Review the plan.
3. Run Phase 1.
4. Review scaffold only.
5. Run Phase 2.
6. Run Phase 3.
7. Run Phase 4.
8. Run Phase 5.
9. Run Phase 6.
10. Run Phase 7.
11. Run Phase 8.

Do not combine many phases into one request unless the project is already stable and narrowly scoped.
