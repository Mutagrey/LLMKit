# AGENTS.md

This repository contains a modular Swift Package named **LLMKit** for LLM orchestration on Apple platforms.

The architecture documents in `Docs/Architecture/` are the source of truth. Follow them strictly.

## Read first

Before making changes, always read these files in this order:

1. `Docs/Architecture/LLMKit_Master_Architecture_Blueprint.md`
2. `Docs/Architecture/LLMKit_Package_Scaffold_and_Target_Graph.md`
3. `Docs/Architecture/LLMKit_Module_File_Map.md`
4. `Docs/Architecture/LLMKit_Agent_Execution_Prompt.md`
5. `Package.swift` and existing module `Docs/` for the target you are modifying

Do not start implementation before reading them.

---

## Primary objective

Build and maintain a **strictly modular, scalable, backend-agnostic Swift Package** for:

- Apple Foundation Models
- Core ML local models
- MLX local models
- remote providers
- reusable chat UI and model lifecycle UI

The package must stay clean, layered, and extensible without architectural sprawl.

---

## Hard rules

### 1. Preserve module boundaries
Do not merge layers for convenience.

Allowed architecture shape:

- `LLMCore`
- `LLMProtocols`
- coordination modules
- `LLMOrchestrator`
- backend adapters
- UI modules

Keep dependency direction one-way and aligned with the architecture docs.

### 2. No duplicate domain types
Do not create multiple request/response/domain models for the same concept.

Examples of concepts that must have one source of truth:
- model descriptors
- generation requests
- generation results
- usage metrics
- tool invocation objects
- session identifiers
- install/download state

### 3. No backend leakage into core layers
Do not import backend SDKs or provider-specific DTOs into:
- `LLMCore`
- `LLMProtocols`
- `LLMSessions`
- `LLMPrompting`
- `LLMTools`
- `LLMSafety`
- `LLMObservability`

### 4. No speculative abstractions
Do not add a new protocol, base type, or helper unless it is clearly justified by the current phase.

Avoid:
- generic "Manager" objects
- vague "BaseService" abstractions
- broad helper files
- speculative extension points with no near-term use

### 5. Prefer modern Swift
Use:
- async/await
- actors when state ownership matters
- `Sendable` where correct
- value types by default
- `final` classes when classes are required

Avoid adding Combine unless there is a concrete reason that async sequences cannot solve the problem cleanly.

### 6. Keep files focused
Prefer one primary type per file when practical.

Avoid files like:
- `Helpers.swift`
- `Utils.swift`
- `Extensions.swift`
- `Managers.swift`
- `Common.swift`

### 7. Keep public API minimal
Default to `internal`.
Expose `public` API only intentionally and only when it belongs to the package surface.

### 8. No third-party dependencies without ADR
Before adding any external dependency:
- create or update an ADR in `Docs/ADR/`
- explain why it is needed
- explain alternatives considered
- explain rollback or replacement plan

### 9. UI must stay backend-agnostic
`LLMUIChat` and `LLMUIDownloads` must consume public services only.

UI must not:
- know backend-specific types
- own transport logic
- own persistence details
- implement routing policy

### 10. Model lifecycle must stay separate from inference orchestration
Do not mix:
- model download/install/update/eviction
with
- prompt execution / chat routing / backend selection

### 11. Implement only the requested phase
Do not silently continue into future phases.
Stay within scope.

### 12. Keep docs in sync
Every module must contain and maintain:

- `Docs/Overview.md`
- `Docs/Responsibilities.md`
- `Docs/PublicAPI.md`
- `Docs/DependencyRules.md`
- `Docs/TODO.md`

No module is complete if its documentation is stale.

---

## Required execution order

Unless explicitly instructed otherwise, follow this order:

1. Scaffold package structure
2. Implement `LLMCore`
3. Implement `LLMProtocols`
4. Implement supporting coordination modules:
   - `LLMSessions`
   - `LLMPrompting`
   - `LLMTools`
   - `LLMSafety`
   - `LLMObservability`
   - `LLMStorage`
   - `LLMDeviceProfiling`
   - `LLMModelLifecycle`
5. Implement `LLMOrchestrator`
6. Implement backend adapters:
   - `LLMBackendFoundationModels`
   - `LLMBackendRemote`
   - `LLMBackendCoreML`
   - `LLMBackendMLX`
7. Implement UI modules:
   - `LLMUIChat`
   - `LLMUIDownloads`
8. Expand tests, fixtures, examples

Do not invert this order unless explicitly requested.

---

## Module-specific intent

### LLMCore
Owns pure domain types only.

### LLMProtocols
Owns contracts between high-level services and implementations.

### Coordination modules
Own state shaping, prompting, tools, safety, observability, storage, profiling, lifecycle.

### LLMOrchestrator
Owns routing, planning, fallback, and service composition.

### Backend adapters
Own SDK-specific and provider-specific execution details.

### UI modules
Own presentation only.

---

## Required change discipline

Before major code generation or refactor:

1. Briefly state the plan.
2. Keep scope narrow.
3. Respect the current phase.
4. Mention any uncertainty before coding.
5. If deviating from architecture docs, document the deviation in an ADR.

---

## Required reporting format

At the end of each task, report:

1. Files created or changed
2. What was implemented
3. Any simplifications or merges
4. Any deviations from the architecture docs
5. Remaining risks or follow-up items

Keep the report concise and concrete.

---

## Testing rules

- Add focused tests around public invariants and routing behavior.
- Prefer narrow tests over broad fragile integration tests early.
- Do not create large test harnesses prematurely.
- Add tests as each module’s API stabilizes.

---

## Anti-sprawl reminders

Do not:
- collapse multiple responsibilities into one large type
- create giant god objects
- leak UI concerns into orchestration
- leak backend concerns into core models
- create temporary duplicate DTOs
- add hidden singleton state
- scatter cross-module logic through random extensions

When in doubt:
1. preserve boundaries
2. reduce surface area
3. prefer composition
4. avoid duplication
5. document decisions

---

## Definition of done for a phase

A phase is done only when:
- code for that phase exists
- tests for the introduced API are added where appropriate
- per-module docs are updated
- there are no obvious architecture violations
- no unapproved third-party dependencies were added

---

## Preferred working style

- Think first, then edit
- Keep each pass small and disciplined
- Avoid rewriting modules that are out of scope
- Do not chase hypothetical future features
- Optimize for clarity, maintainability, and architectural integrity
