# LLMKit Package Scaffold and Target Dependency Graph

## Purpose

This document is the implementation companion to the master architecture blueprint.

Its role is to give the agent a **concrete package scaffold**, **target dependency graph**, **module boundaries**, and a **starter `Package.swift`** strategy so the project can be created with minimal ambiguity and minimal architectural drift.

The agent must treat this document as executable scaffolding guidance, not as optional commentary.

---

## Primary goals

1. Create a modular Swift Package with strict layered boundaries.
2. Prevent architectural sprawl by enforcing one-way dependencies.
3. Keep public API small and stable.
4. Keep backend-specific details isolated from application-facing layers.
5. Prefer async/await, actors, Sendable, value types, and modern Apple SDK patterns.
6. Avoid duplicated abstractions, duplicated DTOs, and duplicated orchestration logic.
7. Create `Docs/` and `ADR/` files per module from the start so the structure stays documented as it grows.

---

## Package layout

```text
LLMKit/
├─ Package.swift
├─ README.md
├─ Docs/
│  ├─ Architecture/
│  │  ├─ Overview.md
│  │  ├─ DependencyGraph.md
│  │  ├─ LayerRules.md
│  │  ├─ CapabilityRouting.md
│  │  └─ ModelLifecycle.md
│  ├─ ADR/
│  │  ├─ ADR-001-Modularization.md
│  │  ├─ ADR-002-CapabilityDrivenRouting.md
│  │  ├─ ADR-003-SessionOwnership.md
│  │  ├─ ADR-004-ModelLifecycleSeparation.md
│  │  └─ ADR-005-UIIsolation.md
│  └─ Agent/
│     ├─ AgentExecutionPlan.md
│     ├─ WorkRules.md
│     └─ ProgressTemplate.md
├─ Sources/
│  ├─ LLMCore/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ PublicTypes.md
│  │  │  └─ NonGoals.md
│  │  └─ ...
│  ├─ LLMProtocols/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ ServiceContracts.md
│  │  │  └─ ConcurrencyRules.md
│  │  └─ ...
│  ├─ LLMOrchestrator/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ RoutingRules.md
│  │  │  └─ FallbackRules.md
│  │  └─ ...
│  ├─ LLMSessions/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ SessionLifecycle.md
│  │  │  └─ MemoryPolicy.md
│  │  └─ ...
│  ├─ LLMPrompting/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ PromptRegistry.md
│  │  │  └─ TruncationPolicy.md
│  │  └─ ...
│  ├─ LLMTools/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ ToolContracts.md
│  │  │  └─ ExecutionPolicy.md
│  │  └─ ...
│  ├─ LLMSafety/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ PolicyHooks.md
│  │  │  └─ RedactionRules.md
│  │  └─ ...
│  ├─ LLMObservability/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ Metrics.md
│  │  │  └─ LoggingPolicy.md
│  │  └─ ...
│  ├─ LLMModelLifecycle/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ InstallStateMachine.md
│  │  │  └─ StoragePolicy.md
│  │  └─ ...
│  ├─ LLMStorage/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ PersistenceBoundaries.md
│  │  │  └─ CachePolicy.md
│  │  └─ ...
│  ├─ LLMDeviceProfiling/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ HardwareSignals.md
│  │  │  └─ RoutingInputs.md
│  │  └─ ...
│  ├─ LLMNetworking/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ HTTPPolicy.md
│  │  │  └─ StreamingTransport.md
│  │  └─ ...
│  ├─ LLMBackendFoundationModels/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ Availability.md
│  │  │  └─ MappingRules.md
│  │  └─ ...
│  ├─ LLMBackendCoreML/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ RuntimeLoading.md
│  │  │  └─ Limits.md
│  │  └─ ...
│  ├─ LLMBackendMLX/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ ExperimentalStatus.md
│  │  │  └─ ModelSupport.md
│  │  └─ ...
│  ├─ LLMBackendRemote/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ ProviderAbstraction.md
│  │  │  └─ SSEStreaming.md
│  │  └─ ...
│  ├─ LLMUIChat/
│  │  ├─ Docs/
│  │  │  ├─ Overview.md
│  │  │  ├─ StateOwnership.md
│  │  │  └─ Theming.md
│  │  └─ ...
│  └─ LLMUIModels/
│     ├─ Docs/
│     │  ├─ Overview.md
│     │  ├─ InstallProgress.md
│     │  └─ ErrorPresentation.md
│     └─ ...
└─ Tests/
   ├─ LLMCoreTests/
   ├─ LLMProtocolsTests/
   ├─ LLMOrchestratorTests/
   ├─ LLMSessionsTests/
   ├─ LLMPromptingTests/
   ├─ LLMToolsTests/
   ├─ LLMSafetyTests/
   ├─ LLMObservabilityTests/
   ├─ LLMModelLifecycleTests/
   ├─ LLMStorageTests/
   ├─ LLMDeviceProfilingTests/
   ├─ LLMNetworkingTests/
   ├─ LLMBackendFoundationModelsTests/
   ├─ LLMBackendCoreMLTests/
   ├─ LLMBackendMLXTests/
   ├─ LLMBackendRemoteTests/
   ├─ LLMUIChatTests/
   └─ LLMUIModelsTests/
```

---

## Layering rules

The dependency direction must remain one-way.

```text
UI
  ↓
Application-facing services
  ↓
Orchestration / Sessions / Prompting / Tools / Safety / Observability
  ↓
Protocols + Core domain
  ↓
Backend adapters / Networking / Storage / Device profiling / Model lifecycle
```

### Hard dependency rules

- `LLMCore` must depend on nothing except Foundation and very lightweight system modules if required.
- `LLMProtocols` may depend only on `LLMCore`.
- `LLMOrchestrator` may depend on:
  - `LLMCore`
  - `LLMProtocols`
  - `LLMSessions`
  - `LLMPrompting`
  - `LLMTools`
  - `LLMSafety`
  - `LLMObservability`
  - `LLMModelLifecycle`
  - `LLMDeviceProfiling`
- Backend modules must not depend on UI modules.
- UI modules must not contain backend-specific logic.
- `LLMNetworking` must not know domain policies.
- `LLMModelLifecycle` must not contain inference orchestration.
- `LLMSessions` must not own model download logic.
- `LLMPrompting` must not call backend SDKs directly.
- `LLMStorage` must not depend on UI or orchestration.
- `LLMCore` must not import backend-specific frameworks.

---

## Target responsibilities

## 1. LLMCore

The semantic center of the package.

Contains:
- `ModelID`
- `ModelFamily`
- `BackendKind`
- `ModelCapability`
- `ExecutionRequirement`
- `QualityTier`
- `GenerationRequest`
- `GenerationResult`
- `GenerationEvent`
- `ChatMessage`
- `ToolDefinition`
- `ToolInvocation`
- `ToolResult`
- `UsageMetrics`
- `TokenEstimate`
- `SessionID`
- `AvailabilityStatus`
- `DownloadState`
- `InstallState`
- `LLMError`

Must stay:
- value-oriented
- protocol-light
- dependency-light
- UI-free
- SDK-free

---

## 2. LLMProtocols

Contains service contracts and backend interfaces.

Examples:
- `LanguageGenerationService`
- `ChatService`
- `StructuredGenerationService`
- `EmbeddingService`
- `SessionStore`
- `ToolExecutor`
- `ModelBackend`
- `ModelCatalogProviding`
- `ModelDownloader`
- `MetricsSink`
- `SafetyPolicyEvaluating`

This is the boundary layer between use cases and implementations.

---

## 3. LLMOrchestrator

The runtime decision engine.

Contains:
- `ModelRouter`
- `ExecutionPlanner`
- `FallbackCoordinator`
- `RequestNormalizer`
- `InferenceCoordinator`
- `CapabilityMatcher`
- `ExecutionContextBuilder`

Responsibilities:
- choose model/backend
- apply policy
- run fallback
- normalize request flow
- route telemetry hooks
- coordinate tool execution pipeline

Must not:
- perform raw HTTP
- store files directly
- render UI
- know view state

---

## 4. LLMSessions

Owns conversational state.

Contains:
- `SessionCoordinator`
- `ConversationTranscript`
- `SessionSnapshot`
- `SessionCompressor`
- `SessionTruncationPolicy`
- `ContextWindowManager`

Responsibilities:
- session creation/resume/close
- history ownership
- transcript summarization hooks
- context compression boundaries
- persistence integration via protocol

Must not:
- choose models directly
- download models
- own UI formatting

---

## 5. LLMPrompting

Owns prompt composition.

Contains:
- `PromptTemplate`
- `PromptRegistry`
- `PromptAssembler`
- `SystemPromptProvider`
- `PromptVersion`
- `PromptDebugSnapshot`

Responsibilities:
- prompt fragments
- role separation
- localization hooks
- reusable task prompts
- deterministic prompt assembly
- prompt truncation inputs

Must not:
- execute requests
- own session store
- call remote APIs directly

---

## 6. LLMTools

Owns generic tool-calling abstractions.

Contains:
- `LLMTool`
- `ToolRegistry`
- `ToolSchemaEncoder`
- `ToolInvocationDecoder`
- `ToolExecutionCoordinator`

Responsibilities:
- abstract tools independent of backend
- validate tool arguments
- map tool definitions into backend-specific schemas
- normalize tool outputs back into core domain types

Must not:
- contain app-specific tools
- depend on chat UI
- hardcode any one backend strategy

---

## 7. LLMSafety

Owns policy hooks.

Contains:
- `SafetyPolicy`
- `InputGuard`
- `OutputGuard`
- `PIIRedactor`
- `ToolPermissionPolicy`
- `GenerationBudgetPolicy`

Responsibilities:
- input redaction hooks
- output moderation hooks
- allow/deny tool usage
- apply token and cost limits
- inject safe-failure behavior

---

## 8. LLMObservability

Owns metrics and logs.

Contains:
- `TelemetryEvent`
- `LatencyMetric`
- `GenerationTrace`
- `MetricsCollector`
- `LoggerAdapter`
- `DebugSnapshotEmitter`

Responsibilities:
- TTFT
- throughput
- cold/warm path measurements
- fallback reason tracking
- model load timing
- cancellation reporting
- structured output validation rate

Must not:
- choose routing
- own view models
- contain networking code

---

## 9. LLMModelLifecycle

Owns model install/uninstall/update lifecycle.

Contains:
- `ModelCatalog`
- `ModelManifest`
- `ModelInstaller`
- `ModelVerifier`
- `ModelCompiler`
- `ModelWarmupManager`
- `ModelEvictionManager`
- `InstalledModelIndex`

Responsibilities:
- discover models
- download/install/update/remove
- verify integrity
- compile if needed
- prewarm if supported
- enforce disk/storage policy

Must not:
- own session history
- render progress UI directly
- execute prompts

---

## 10. LLMStorage

Owns persistence primitives.

Contains:
- `FileStore`
- `ManifestStore`
- `SessionPersistenceStore`
- `CacheStore`
- `SecureMetadataStore`

Responsibilities:
- file system paths
- metadata persistence
- session snapshots
- cache indexes
- cleanup primitives

---

## 11. LLMDeviceProfiling

Owns device/runtime signal collection.

Contains:
- `DeviceProfile`
- `RuntimeConstraints`
- `MemoryPressureSnapshot`
- `ThermalStateSnapshot`
- `ExecutionBudgetSnapshot`

Responsibilities:
- gather hardware/software constraints
- provide router inputs
- report device suitability for candidate models

---

## 12. LLMNetworking

Owns transport-level remote networking only.

Contains:
- `HTTPRequestBuilder`
- `StreamingHTTPClient`
- `SSEParser`
- `RetryPolicy`
- `AuthHeaderProvider`

Responsibilities:
- remote transport
- streaming transport
- request retry
- cancellation bridging
- auth injection

Must not:
- define provider business logic at orchestration level
- own domain types beyond mapping boundaries

---

## 13. Backend targets

### LLMBackendFoundationModels
- wraps Apple Foundation Models backend
- maps package requests to system model requests
- isolates framework availability and mapping details

### LLMBackendCoreML
- wraps local Core ML model loading/inference
- isolates compilation/loading/runtime constraints

### LLMBackendMLX
- experimental path for MLX-backed local models such as Qwen/Gemma families
- must clearly document supported model families and maturity

### LLMBackendRemote
- wraps remote provider transport
- supports provider adapters without leaking provider-specific DTOs into upper layers

---

## 14. UI targets

### LLMUIChat
Reusable SwiftUI chat presentation layer.

Contains:
- `ChatScreen`
- `ChatComposerView`
- `StreamingMessageView`
- `ChatTimelineView`
- `ToolInvocationView`
- `TypingStateView`
- `ChatTheme`
- `ChatViewModel`

Rules:
- must consume public services only
- must not know which backend is being used
- must not own routing logic
- must not mutate persistence directly except through public service abstractions

### LLMUIModels
Reusable UI for model catalog, installs, progress, and storage usage.

Contains:
- `ModelListView`
- `ModelRowView`
- `ModelDetailView`
- `ModelInstallProgressView`
- `StorageUsageView`
- `ModelStorageSummary`

Rules:
- consumes lifecycle/status streams only
- never touches backend SDK directly

### LLMUIStorage
Reusable SwiftUI storage visualization primitives shared by UI modules.

Contains:
- `StorageUsageBarView`
- `StorageUsageBarSegment`

Rules:
- consumes host-provided byte segments only
- must not import lifecycle, storage services, networking, orchestration, or backend targets

---

## Starter package products

Recommended products:

- `LLMKitCore`
- `LLMKitApple`
- `LLMKitLocal`
- `LLMKitRemote`
- `LLMKitUI`
- `LLMKitFull`

This allows consumers to include only the surface they need.

---

## Recommended starter Package.swift

This is a starter scaffold. The agent may refine platform versions and dependency declarations if needed, but it must preserve the dependency graph and modular intent.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "LLMKitCore",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling"
            ]
        ),
        .library(
            name: "LLMKitApple",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling",
                "LLMBackendFoundationModels",
                "LLMBackendCoreML"
            ]
        ),
        .library(
            name: "LLMKitLocal",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling",
                "LLMBackendCoreML",
                "LLMBackendMLX"
            ]
        ),
        .library(
            name: "LLMKitRemote",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling",
                "LLMNetworking",
                "LLMBackendRemote"
            ]
        ),
        .library(
            name: "LLMKitUI",
            targets: [
                "LLMUIStorage",
                "LLMUIChat",
                "LLMUIModels"
            ]
        ),
        .library(
            name: "LLMKitFull",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling",
                "LLMNetworking",
                "LLMBackendFoundationModels",
                "LLMBackendCoreML",
                "LLMBackendMLX",
                "LLMBackendRemote",
                "LLMUIStorage",
                "LLMUIChat",
                "LLMUIModels"
            ]
        )
    ],
    dependencies: [
        // Add external packages only after the agent creates ADRs documenting why they are needed.
        // Example placeholders:
        // .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.0.0"),
        // .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "LLMCore"
        ),
        .target(
            name: "LLMProtocols",
            dependencies: [
                "LLMCore"
            ]
        ),
        .target(
            name: "LLMSessions",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMPrompting",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMTools",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMSafety",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMObservability",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMStorage",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMDeviceProfiling",
            dependencies: [
                "LLMCore"
            ]
        ),
        .target(
            name: "LLMNetworking",
            dependencies: [
                "LLMCore"
            ]
        ),
        .target(
            name: "LLMModelLifecycle",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMStorage",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMOrchestrator",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMDeviceProfiling"
            ]
        ),
        .target(
            name: "LLMBackendFoundationModels",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMBackendCoreML",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMBackendMLX",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMBackendRemote",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMNetworking",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMUIStorage"
        ),
        .target(
            name: "LLMUIChat",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMTools",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMUIModels",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability",
                "LLMUIStorage"
            ]
        ),

        .testTarget(
            name: "LLMCoreTests",
            dependencies: ["LLMCore"]
        ),
        .testTarget(
            name: "LLMProtocolsTests",
            dependencies: ["LLMProtocols"]
        ),
        .testTarget(
            name: "LLMSessionsTests",
            dependencies: ["LLMSessions"]
        ),
        .testTarget(
            name: "LLMPromptingTests",
            dependencies: ["LLMPrompting"]
        ),
        .testTarget(
            name: "LLMToolsTests",
            dependencies: ["LLMTools"]
        ),
        .testTarget(
            name: "LLMSafetyTests",
            dependencies: ["LLMSafety"]
        ),
        .testTarget(
            name: "LLMObservabilityTests",
            dependencies: ["LLMObservability"]
        ),
        .testTarget(
            name: "LLMStorageTests",
            dependencies: ["LLMStorage"]
        ),
        .testTarget(
            name: "LLMDeviceProfilingTests",
            dependencies: ["LLMDeviceProfiling"]
        ),
        .testTarget(
            name: "LLMNetworkingTests",
            dependencies: ["LLMNetworking"]
        ),
        .testTarget(
            name: "LLMModelLifecycleTests",
            dependencies: ["LLMModelLifecycle"]
        ),
        .testTarget(
            name: "LLMOrchestratorTests",
            dependencies: ["LLMOrchestrator"]
        ),
        .testTarget(
            name: "LLMBackendFoundationModelsTests",
            dependencies: ["LLMBackendFoundationModels"]
        ),
        .testTarget(
            name: "LLMBackendCoreMLTests",
            dependencies: ["LLMBackendCoreML"]
        ),
        .testTarget(
            name: "LLMBackendMLXTests",
            dependencies: ["LLMBackendMLX"]
        ),
        .testTarget(
            name: "LLMBackendRemoteTests",
            dependencies: ["LLMBackendRemote"]
        ),
        .testTarget(
            name: "LLMUIChatTests",
            dependencies: ["LLMUIChat"]
        ),
        .testTarget(
            name: "LLMUIModelsTests",
            dependencies: ["LLMUIModels"]
        )
    ]
)
```

---

## Simplified target dependency graph

```text
LLMCore
└─ LLMProtocols

LLMProtocols
├─ LLMSessions
├─ LLMPrompting
├─ LLMTools
├─ LLMSafety
├─ LLMObservability
├─ LLMStorage
├─ LLMModelLifecycle
├─ LLMOrchestrator
├─ LLMBackendFoundationModels
├─ LLMBackendCoreML
├─ LLMBackendMLX
├─ LLMBackendRemote
├─ LLMUIChat
└─ LLMUIModels

LLMNetworking
└─ LLMBackendRemote

LLMStorage + LLMObservability
└─ LLMModelLifecycle

LLMSessions + LLMPrompting + LLMTools + LLMSafety + LLMObservability + LLMModelLifecycle + LLMDeviceProfiling
└─ LLMOrchestrator
```

---

## Required docs per module

Every module must contain a `Docs/` folder with the following files at minimum:

```text
Docs/
├─ Overview.md
├─ Responsibilities.md
├─ PublicAPI.md
├─ DependencyRules.md
└─ TODO.md
```

### Rules for these docs

- `Overview.md` describes the purpose of the module.
- `Responsibilities.md` lists what the module owns and explicitly what it does not own.
- `PublicAPI.md` documents public types and their intended use.
- `DependencyRules.md` states allowed imports and forbidden imports.
- `TODO.md` contains scoped future work only for that module.

No module may be created without its docs.

---

## Required ADR flow

Before introducing:
- a new external package
- a new backend
- a new persistence mechanism
- a new UI state container
- a new cross-cutting abstraction

the agent must add or update an ADR in `Docs/ADR/`.

ADR template:

```text
Title
Status
Context
Decision
Alternatives considered
Consequences
Migration / rollback plan
```

---

## Folder scaffold sequence for the agent

The agent must work in this order.

### Phase 1
Create:
- package root
- `Package.swift`
- top-level `Docs/`
- `Sources/`
- `Tests/`
- all target folders
- all per-target `Docs/`

### Phase 2
Create only empty or near-empty scaffolds:
- marker files
- placeholder `Overview.md`
- placeholder `Responsibilities.md`
- placeholder `PublicAPI.md`
- placeholder `DependencyRules.md`
- placeholder `TODO.md`

### Phase 3
Define core domain types in `LLMCore`

### Phase 4
Define public protocols in `LLMProtocols`

### Phase 5
Implement non-backend coordination modules

### Phase 6
Implement backend adapters

### Phase 7
Implement UI modules

### Phase 8
Add examples/tests/fixtures

This order must not be inverted.

---

## Required coding rules for the agent

1. Prefer `struct`, `enum`, protocol, and actor appropriately.
2. Use `final` for classes unless open inheritance is required.
3. Default to `internal`, expose `public` only intentionally.
4. Use `Sendable` wherever it is correct.
5. Prefer async/await; use `AsyncStream` or `AsyncThrowingStream` for streaming.
6. Avoid Combine unless there is a concrete reason that async sequences cannot cover the need.
7. Keep DTOs in one place; do not clone request/response models per module without strong reason.
8. Do not place convenience logic in `LLMCore`.
9. Do not let UI state models leak into service or backend layers.
10. Do not let provider-specific naming leak into public generic types.
11. Create tests beside each module as soon as the public API for that module stabilizes.
12. Prefer small files with one major responsibility.
13. Prefer composition over inheritance.
14. Keep imports minimal.
15. No hidden singleton state.

---

## Required naming conventions

### Protocols
- noun or role-based:
  - `ModelBackend`
  - `SessionStore`
  - `MetricsSink`

Avoid vague names like:
- `ManagerProtocol`
- `ServiceProtocol`
- `BaseHandler`

### Concrete types
- capability-oriented:
  - `ModelRouter`
  - `ExecutionPlanner`
  - `PromptAssembler`
  - `ModelInstaller`

Avoid:
- `MainManager`
- `DefaultService`
- `CommonHelper`

### Files
File names must match primary type names when practical.

---

## Public API boundary guidance

Public API should be exposed through a small number of stable entry points.

Recommended entry façade:

```swift
public struct LLMKitContainer {
    public let generation: LanguageGenerationService
    public let chat: ChatService
    public let structured: StructuredGenerationService
    public let embeddings: EmbeddingService?
    public let lifecycle: ModelLifecycleService
    public let sessions: SessionService
}
```

Construction should happen through factory/builders, for example:

```swift
public enum LLMKitFactory {
    public static func makeLocalFirst() throws -> LLMKitContainer
    public static func makeAppleFirst() throws -> LLMKitContainer
    public static func makeRemoteOnly(configuration: RemoteConfiguration) throws -> LLMKitContainer
}
```

The agent may refine naming, but the public entry pattern must stay compact.

---

## UI architecture rules

For `LLMUIChat`:

- View models may depend on public services only.
- Message timeline rendering must be generic and backend-agnostic.
- Streaming state must be modeled explicitly.
- Tool-calling UI must be composable and optional.
- Markdown rendering must be swappable.
- Attachments must be abstracted behind input items, not hardcoded to one media type.

Suggested UI types:
- `ChatViewModel`
- `ChatComposerState`
- `TimelineSection`
- `RenderedMessage`
- `MessageStreamingState`
- `AttachmentDraft`
- `ChatTheme`
- `ChatInputPolicy`

For `LLMUIModels`:
- install state is read-only from the UI perspective
- actions must go through lifecycle service
- progress presentation must be independent of a specific downloader implementation

---

## What the agent must not do

- Do not start by implementing one giant all-in-one target.
- Do not add third-party dependencies before ADR review.
- Do not place backend SDK imports in high-level modules.
- Do not create app-specific feature code in the package.
- Do not create “temporary” duplicate types that later need merging.
- Do not build a UI-first architecture that forces business logic into view models.
- Do not hide cross-module coupling inside extensions scattered across targets.

---

## Minimal bootstrap deliverables

The first clean scaffold commit should contain:

1. `Package.swift`
2. full `Sources/` tree
3. full `Tests/` tree
4. root docs
5. per-module docs
6. ADR stubs
7. placeholder README
8. zero or near-zero implementation logic

This first commit is structural only.

---

## Second-stage deliverables

After scaffold:

1. implement `LLMCore`
2. implement `LLMProtocols`
3. implement `LLMSessions`
4. implement `LLMPrompting`
5. implement `LLMTools`
6. implement `LLMSafety`
7. implement `LLMObservability`
8. implement `LLMStorage`
9. implement `LLMDeviceProfiling`
10. implement `LLMModelLifecycle`
11. implement `LLMOrchestrator`

Only then start backend adapters.

---

## Suggested initial file seeds per module

At minimum, each module should start with:

- `ModuleNameExports.swift`
- one `README`-like doc under `Docs/`
- 1–3 core types only

The agent should resist creating dozens of speculative empty types.

---

## Optional follow-up deliverables

After the package skeleton is stable, generate:

- `Examples/LLMKitDemoApp`
- `Examples/LLMKitChatPlayground`
- `Fixtures/`
- `Scripts/bootstrap_docs.sh`
- `Scripts/validate_module_docs.sh`
- `Scripts/check_dependency_rules.sh`

---

## Final instruction to the agent

Use this document as the source of truth for package scaffolding and modular dependency control.

When uncertain:
1. preserve the layer boundaries
2. reduce public API surface
3. prefer composition
4. avoid duplication
5. document the decision in ADR form
```
