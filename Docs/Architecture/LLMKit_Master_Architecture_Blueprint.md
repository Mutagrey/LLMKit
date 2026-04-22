# LLMKit — Master Architecture Blueprint for Agent

## 1. Document purpose

This document is the **single source of truth** for the initial design and scaffolding of a modular Swift Package that integrates:

- Apple Foundation Models / Apple Intelligence
- local custom LLMs
- MLX-based local models
- Core ML based local models
- remote LLM providers
- chat UI and related AI application building blocks

The package must be designed as a **scalable AI runtime platform for Apple apps**, not as a thin wrapper around one provider.

This document is written for an implementation agent. The agent must follow it strictly.

---

## 2. Agent operating mode

### Mandatory execution order

The agent must work in the following order and **must not skip steps**:

1. Create folder structure.
2. Create documentation skeletons for every module.
3. Create root ADR files.
4. Create package targets and empty public entry points.
5. Create core domain contracts and protocols.
6. Create orchestration layer.
7. Create lifecycle layer.
8. Create backend adapters.
9. Create UI modules.
10. Add tests.
11. Only then add incremental implementation details.

### Before writing real feature code

The agent must first establish:

- clear target boundaries
- dependency directions
- ownership of each module
- naming consistency
- documentation for every module
- ADRs for architectural decisions

### Forbidden behavior

The agent must not:

- create a giant singleton manager
- mix UI concerns with runtime/inference concerns
- mix backend-specific code into generic feature modules
- duplicate transport, parsing, or session logic across backends
- introduce Combine-first design where async/await and AsyncSequence are more appropriate
- add third-party frameworks unless explicitly justified in a module decision document
- implement "temporary" shortcuts that violate layering
- let concrete backends leak into app-facing APIs
- use one module as a miscellaneous dumping ground

---

## 3. Product vision

The package is a reusable Apple-platform AI runtime that allows applications to say:

- what task they need
- what constraints they have
- what capabilities are required
- whether the request must be offline, low-latency, structured, tool-capable, etc.

The runtime then selects the correct backend and model according to policy.

### Core vision

The app must depend on **capabilities and use-cases**, not on concrete providers.

### Architectural principle

Use **capability-driven orchestration**.

Do not design around:

- "Apple backend"
- "Qwen backend"
- "Gemma backend"
- "OpenAI backend"

Design around:

- chat generation
- structured generation
- tool calling
- embeddings
- summarization
- extraction
- classification
- offline execution
- fallback policies
- model lifecycle

---

## 4. Technical baseline

### Platform assumptions

- Swift 6+
- strict concurrency enabled where practical
- iOS 18+ minimum for app integration targets unless a target explicitly requires newer OS APIs
- package must support progressive feature gating for newer APIs
- design for iOS, iPadOS, macOS, optionally visionOS

### Preferred modern language/platform features

Use these by default:

- `async/await`
- `AsyncSequence` / `AsyncThrowingStream`
- `actor` for mutable shared state
- `Sendable`
- `@Observable` in UI-facing app/demo layers where appropriate
- `swift-testing` for new tests
- `OSLog` / `Logger`
- `swift package` modular targets

### Use only when justified

- Combine
- NotificationCenter
- legacy callback wrappers
- custom thread locking outside actor isolation

---

## 5. Package philosophy

This package is not only for chat. It must support future AI application patterns.

### Primary package responsibilities

- unified LLM inference API
- model routing and backend selection
- local/remote model lifecycle management
- structured output generation
- tool calling abstraction
- session management
- streaming
- observability / diagnostics
- safety and policy hooks
- optional reusable SwiftUI chat UI

### Non-goals for the first implementation

- full RAG stack inside the initial core
- full-blown vector database inside core
- training pipeline inside the runtime package
- full multimodal VLM system in MVP
- automatic fine-tuning system in MVP
- app-specific persistence assumptions in core

---

## 6. Required package layout

The package must be organized into multiple targets with strict dependency direction.

```text
LLMKit/
  Package.swift
  README.md

  Docs/
    Master/
      Vision.md
      Scope.md
      Roadmap.md
      Glossary.md
      DependencyRules.md
      CodingStandards.md
      TestingStrategy.md
      UIPrinciples.md
      PerformancePrinciples.md
      SecurityAndPrivacy.md
    ADR/
      ADR-001-capability-driven-architecture.md
      ADR-002-backend-adapter-boundary.md
      ADR-003-async-await-first.md
      ADR-004-model-lifecycle-separation.md
      ADR-005-structured-output-first-class.md
      ADR-006-tool-calling-abstraction.md
      ADR-007-ui-is-optional-layer.md
      ADR-008-no-singleton-runtime.md

  Sources/
    LLMCore/
      Docs/
      Public/
      Internal/
    LLMProtocols/
      Docs/
      Public/
      Internal/
    LLMOrchestrator/
      Docs/
      Public/
      Internal/
    LLMSessions/
      Docs/
      Public/
      Internal/
    LLMPrompting/
      Docs/
      Public/
      Internal/
    LLMTools/
      Docs/
      Public/
      Internal/
    LLMSafety/
      Docs/
      Public/
      Internal/
    LLMObservability/
      Docs/
      Public/
      Internal/
    LLMModelLifecycle/
      Docs/
      Public/
      Internal/
    LLMStorage/
      Docs/
      Public/
      Internal/
    LLMDevice/
      Docs/
      Public/
      Internal/
    LLMNetworking/
      Docs/
      Public/
      Internal/

    Backends/
      LLMBackendFoundationModels/
        Docs/
        Public/
        Internal/
      LLMBackendCoreML/
        Docs/
        Public/
        Internal/
      LLMBackendMLX/
        Docs/
        Public/
        Internal/
      LLMBackendRemote/
        Docs/
        Public/
        Internal/
      LLMBackendExecuTorch/
        Docs/
        Public/
        Internal/
      LLMBackendONNXRuntime/
        Docs/
        Public/
        Internal/

    UI/
      LLMUIChat/
        Docs/
        Public/
        Internal/
      LLMUIDownloads/
        Docs/
        Public/
        Internal/
      LLMUIPrompts/
        Docs/
        Public/
        Internal/

  Tests/
    LLMCoreTests/
    LLMProtocolsTests/
    LLMOrchestratorTests/
    LLMSessionsTests/
    LLMPromptingTests/
    LLMToolsTests/
    LLMSafetyTests/
    LLMObservabilityTests/
    LLMModelLifecycleTests/
    LLMStorageTests/
    LLMDeviceTests/
    LLMNetworkingTests/
    LLMBackendFoundationModelsTests/
    LLMBackendCoreMLTests/
    LLMBackendMLXTests/
    LLMBackendRemoteTests/
    LLMUIChatTests/
    IntegrationTests/
    SnapshotTests/
```

### Notes

- `ExecuTorch` and `ONNXRuntime` targets may be created as placeholders initially if not implemented in phase 1.
- UI targets must remain optional.
- backend modules must never be imported directly by app code unless explicitly intended.

---

## 7. Required docs inside every module

Each target folder must include a `Docs/` folder with at least these files:

- `README.md`
- `Responsibility.md`
- `PublicAPI.md`
- `InternalDesign.md`
- `DependencyRules.md`
- `Testing.md`
- `FutureWork.md`

### Meaning of each file

#### `README.md`
Contains:

- what the module is
- why it exists
- what it owns
- what it does not own
- which modules may depend on it

#### `Responsibility.md`
Contains:

- exact responsibility boundaries
- explicit non-responsibilities
- examples of valid and invalid logic placement

#### `PublicAPI.md`
Contains:

- public entry points
- important public types
- intended usage patterns
- stability expectations

#### `InternalDesign.md`
Contains:

- internal components
- state flows
- important actors/services/helpers
- threading/concurrency decisions

#### `DependencyRules.md`
Contains:

- what this module may import
- what must not import this module
- examples of forbidden dependencies

#### `Testing.md`
Contains:

- unit test strategy
- contract tests
- edge cases
- fixtures or mocks needed

#### `FutureWork.md`
Contains:

- deferred ideas
- known limitations
- extensibility notes

---

## 8. Root documentation the agent must create first

The following root docs must be created before implementation:

### `Docs/Master/Vision.md`
Describe the package as a modular AI runtime platform.

### `Docs/Master/Scope.md`
Define in-scope and out-of-scope responsibilities.

### `Docs/Master/Roadmap.md`
Phased rollout plan:

- phase 0: structure/docs/contracts
- phase 1: orchestration + basic backends
- phase 2: lifecycle + downloads + UI
- phase 3: advanced capabilities

### `Docs/Master/Glossary.md`
Define shared terms:

- backend
- capability
- model descriptor
- session
- tool
- structured output
- lifecycle
- routing policy
- warmup
- eviction
- transcript compression

### `Docs/Master/DependencyRules.md`
Define package-wide dependency rules.

### `Docs/Master/CodingStandards.md`
Define implementation rules.

### `Docs/Master/TestingStrategy.md`
Define testing pyramid.

### `Docs/Master/UIPrinciples.md`
Define reusable UI rules.

### `Docs/Master/PerformancePrinciples.md`
Define startup, memory, streaming, warmup, battery principles.

### `Docs/Master/SecurityAndPrivacy.md`
Define privacy, model integrity, secret handling, logging redaction.

---

## 9. ADRs the agent must create

Create at least these architecture decision records:

### ADR-001 — Capability-driven architecture
Why routing is based on requested capabilities rather than provider enums.

### ADR-002 — Backend adapter boundary
Why each runtime/provider is isolated behind backend adapters.

### ADR-003 — Async/await first
Why async/await and AsyncSequence are preferred over Combine-first design.

### ADR-004 — Model lifecycle separation
Why download/install/storage/eviction is a separate subsystem from inference.

### ADR-005 — Structured output is first-class
Why typed generation must not be an afterthought.

### ADR-006 — Tool calling abstraction
Why tools are represented with generic contracts independent of provider APIs.

### ADR-007 — UI is optional
Why UI is an add-on layer and not part of inference core.

### ADR-008 — No singleton runtime
Why global shared mutable manager is prohibited.

---

## 10. Dependency direction rules

These rules are mandatory.

### Base layers

- `LLMCore` must not depend on any backend.
- `LLMProtocols` may depend on `LLMCore`.
- `LLMOrchestrator` may depend on `LLMCore`, `LLMProtocols`, `LLMSessions`, `LLMTools`, `LLMSafety`, `LLMObservability`, `LLMModelLifecycle`, `LLMDevice`.
- `LLMSessions` may depend on `LLMCore` and `LLMStorage` abstractions only.
- `LLMPrompting` may depend on `LLMCore` and `LLMSessions`.
- `LLMTools` may depend on `LLMCore`.
- `LLMSafety` may depend on `LLMCore`.
- `LLMObservability` may depend on `LLMCore`.
- `LLMModelLifecycle` may depend on `LLMCore`, `LLMNetworking`, `LLMStorage`, `LLMObservability`, `LLMDevice`.
- `LLMStorage` must stay low-level and backend-neutral.
- `LLMDevice` must stay low-level and backend-neutral.
- `LLMNetworking` must remain generic.

### Backends

- Every backend may depend on `LLMCore`, `LLMProtocols`, `LLMObservability`, and narrow helper modules if needed.
- Backends must not import UI modules.
- Backends must not depend on each other.

### UI

- UI modules may depend on core contracts, orchestrator facades, sessions, observability-friendly public state models.
- UI modules must not import provider frameworks directly.

### Absolute prohibitions

- `LLMCore` importing any backend
- UI importing concrete provider SDKs directly
- backend importing another backend
- lifecycle importing UI
- app-facing services exposing provider-native request/response types

---

## 11. Package products recommendation

Define products approximately like this:

- `LLMKitCore`
- `LLMKitRuntime`
- `LLMKitFoundationModels`
- `LLMKitLocal`
- `LLMKitRemote`
- `LLMKitUI`
- `LLMKitFull`

### Suggested grouping

#### `LLMKitCore`
- LLMCore
- LLMProtocols
- LLMSessions
- LLMPrompting
- LLMTools
- LLMSafety
- LLMObservability

#### `LLMKitRuntime`
- LLMOrchestrator
- LLMModelLifecycle
- LLMStorage
- LLMDevice
- LLMNetworking

#### `LLMKitFoundationModels`
- LLMBackendFoundationModels

#### `LLMKitLocal`
- LLMBackendCoreML
- LLMBackendMLX
- optional future backends

#### `LLMKitRemote`
- LLMBackendRemote

#### `LLMKitUI`
- LLMUIChat
- LLMUIDownloads
- LLMUIPrompts

---

## 12. Core domain types that must exist

These must live in `LLMCore`.

### Identity and descriptors

```swift
public struct ModelID: Hashable, Sendable, Codable {
    public let rawValue: String
}

public enum ModelFamily: Hashable, Sendable, Codable {
    case appleFoundation
    case qwen
    case gemma
    case llama
    case mistral
    case custom(String)
}

public enum BackendKind: Hashable, Sendable, Codable {
    case foundationModels
    case coreML
    case mlx
    case remote
    case executorch
    case onnxRuntime
}
```

### Capabilities

```swift
public enum ModelCapability: Hashable, Sendable, Codable {
    case chat
    case completion
    case streaming
    case structuredOutput
    case toolCalling
    case embeddings
    case summarization
    case extraction
    case classification
    case offline
    case multimodalInput
    case lowLatency
    case longContext
    case backgroundExecution
}
```

### Request policies

```swift
public enum QualityTier: String, Sendable, Codable {
    case fast
    case balanced
    case best
}

public enum ExecutionMode: String, Sendable, Codable {
    case offlineOnly
    case preferOffline
    case hybrid
    case remoteAllowed
}

public enum PreferredLatency: String, Sendable, Codable {
    case interactive
    case background
    case relaxed
}
```

### Descriptor

```swift
public struct ModelDescriptor: Sendable, Codable, Hashable {
    public let id: ModelID
    public let displayName: String
    public let family: ModelFamily
    public let backend: BackendKind
    public let capabilities: Set<ModelCapability>
    public let minimumOS: String?
    public let minimumRAMGB: Int?
    public let minimumFreeDiskGB: Int?
    public let supportsStreaming: Bool
    public let supportsTools: Bool
    public let supportsStructuredOutput: Bool
    public let isRemote: Bool
    public let tags: [String]
}
```

### Message and chat

```swift
public enum MessageRole: String, Sendable, Codable {
    case system
    case developer
    case user
    case assistant
    case tool
}

public struct MessageContent: Sendable, Codable, Hashable {
    public let text: String
}

public struct ChatMessage: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public let role: MessageRole
    public let content: MessageContent
    public let createdAt: Date
}
```

### Requests and responses

```swift
public struct ChatRequest: Sendable {
    public let messages: [ChatMessage]
    public let requiredCapabilities: Set<ModelCapability>
    public let executionMode: ExecutionMode
    public let preferredLatency: PreferredLatency
    public let qualityTier: QualityTier
    public let preferredModel: ModelID?
    public let sessionID: SessionID?
}

public struct GenerationRequest: Sendable {
    public let prompt: String
    public let requiredCapabilities: Set<ModelCapability>
    public let executionMode: ExecutionMode
    public let preferredLatency: PreferredLatency
    public let qualityTier: QualityTier
}
```

### Events and usage

```swift
public enum ChatEvent: Sendable {
    case started(ModelDescriptor)
    case delta(String)
    case toolCallRequested(ToolInvocationRequest)
    case completed(ChatResult)
    case failed(LLMError)
}

public struct TokenUsage: Sendable, Codable, Hashable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
}
```

### Errors

```swift
public enum LLMError: Error, Sendable {
    case unavailable
    case unsupportedCapabilities(Set<ModelCapability>)
    case modelNotInstalled(ModelID)
    case downloadFailed(String)
    case verificationFailed
    case compilationFailed
    case executionFailed(String)
    case toolExecutionFailed(String)
    case invalidStructuredOutput(String)
    case cancelled
}
```

---

## 13. Core protocol contracts that must exist

These live in `LLMProtocols`.

### App-facing services

```swift
public protocol ChatService: Sendable {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error>
}

public protocol GenerationService: Sendable {
    func generate(_ request: GenerationRequest) async throws -> GenerationResult
    func stream(_ request: GenerationRequest) -> AsyncThrowingStream<GenerationEvent, Error>
}

public protocol StructuredGenerationService: Sendable {
    func generate<T: Decodable & Sendable>(
        _ type: T.Type,
        request: StructuredRequest
    ) async throws -> T
}

public protocol EmbeddingService: Sendable {
    func embed(_ request: EmbeddingRequest) async throws -> [EmbeddingVector]
}
```

### Backend contracts

```swift
public protocol ModelBackend: Sendable {
    var backendID: BackendKind { get }

    func availability(for descriptor: ModelDescriptor) async -> BackendAvailability
    func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool
    func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle
    func unloadModel(_ handle: LoadedModelHandle) async

    func generate(_ request: BackendGenerationRequest)
        -> AsyncThrowingStream<BackendGenerationEvent, Error>

    func chat(_ request: BackendChatRequest)
        -> AsyncThrowingStream<BackendChatEvent, Error>
}
```

### Lifecycle contracts

```swift
public protocol ModelCatalog: Sendable {
    func availableModels() async throws -> [ModelDescriptor]
    func descriptor(for id: ModelID) async throws -> ModelDescriptor?
}

public protocol ModelInstaller: Sendable {
    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error>
}

public protocol ModelStorage: Sendable {
    func state(for modelID: ModelID) async throws -> InstalledModelState
    func installedModels() async throws -> [InstalledModelRecord]
}
```

### Session contracts

```swift
public protocol SessionStore: Sendable {
    func loadSession(id: SessionID) async throws -> ChatSession?
    func saveSession(_ session: ChatSession) async throws
    func deleteSession(id: SessionID) async throws
}
```

### Tools contracts

```swift
public protocol LLMTool: Sendable {
    var definition: ToolDefinition { get }
    func execute(arguments: ToolArguments, context: ToolExecutionContext) async throws -> ToolResult
}

public protocol ToolRegistry: Sendable {
    func allTools() async -> [ToolDefinition]
    func tool(named name: String) async -> (any LLMTool)?
}
```

### Safety contracts

```swift
public protocol InputPolicyEvaluator: Sendable {
    func evaluate(_ request: SafetyInputRequest) async -> SafetyDecision
}

public protocol OutputPolicyEvaluator: Sendable {
    func evaluate(_ response: SafetyOutputRequest) async -> SafetyDecision
}
```

---

## 14. Orchestration layer design

This is the central decision-making layer and must live in `LLMOrchestrator`.

### Required primary components

- `DefaultChatService`
- `DefaultGenerationService`
- `DefaultStructuredGenerationService`
- `DefaultEmbeddingService`
- `ExecutionPlanner`
- `CapabilityRouter`
- `FallbackCoordinator`
- `BackendRegistry`
- `RequestNormalizer`
- `ResponseAssembler`
- `ToolExecutionCoordinator`
- `StructuredOutputCoordinator`
- `ExecutionBudgetPolicy`
- `CancellationCoordinator`

### Responsibilities

#### `ExecutionPlanner`
Decides execution strategy from:

- requested capabilities
- execution mode
- preferred latency
- quality tier
- device state
- availability of installed models
- online/offline conditions

#### `CapabilityRouter`
Selects best backend/model candidate.

#### `FallbackCoordinator`
Moves to next candidate on failure or unavailability.

#### `ResponseAssembler`
Builds final result from backend stream events.

#### `StructuredOutputCoordinator`
Wraps structured generation, validation, repair strategy.

#### `ToolExecutionCoordinator`
Bridges model tool requests to registered tools and returns tool results back into generation loop.

### Mandatory behavior

- orchestration must not contain provider-specific code
- orchestration must operate on protocol abstractions only
- orchestration must be testable with fake backends

---

## 15. Sessions layer design

Lives in `LLMSessions`.

### Required types

- `SessionID`
- `ChatSession`
- `SessionTranscript`
- `SessionMessageRecord`
- `SessionSummary`
- `ContextWindowPolicy`
- `TranscriptCompactor`
- `SessionPersistenceCoordinator`

### Responsibilities

- session identity
- transcript persistence
- rolling context construction
- transcript truncation
- transcript summarization hooks
- session resume support

### Rules

- sessions must be backend-agnostic
- provider-native session objects must not leak outside backend adapters
- session storage format must be stable and codable

---

## 16. Prompting layer design

Lives in `LLMPrompting`.

### Required components

- `PromptTemplate`
- `PromptFragment`
- `PromptAssemblyContext`
- `PromptAssembler`
- `PromptVersion`
- `PromptRegistry`
- `PromptDebugSnapshot`

### Responsibilities

- system/developer/user prompt assembly
- versioned prompt templates
- locale-aware injection
- context snippets insertion
- debug snapshots for observability

### Rules

- prompts must not be hardcoded everywhere
- prompt fragments must be reusable
- app-level prompts may extend but not break core abstractions

---

## 17. Tools layer design

Lives in `LLMTools`.

### Required components

- `ToolDefinition`
- `ToolSchema`
- `ToolArguments`
- `ToolExecutionContext`
- `ToolResult`
- `DefaultToolRegistry`
- `ToolResultEncoder`

### Responsibilities

- generic tool definition
- schema representation
- tool registry and lookup
- argument decoding and validation
- result encoding back into model-compatible format

### Rules

- tools must be generic and backend-independent
- backends may adapt native provider tool APIs to this abstraction

---

## 18. Safety layer design

Lives in `LLMSafety`.

### Required components

- `SafetyDecision`
- `SafetyReason`
- `SafetyInputRequest`
- `SafetyOutputRequest`
- `CompositeInputPolicyEvaluator`
- `CompositeOutputPolicyEvaluator`
- `PIIRedactor`
- `LoggingRedactionPolicy`

### Responsibilities

- pre-request policy checks
- post-response checks
- redaction hooks for logs
- allow/deny/modify decisions

### Rules

- safety must be composable
- safety must be injectable
- safety must not be hardcoded inside backends

---

## 19. Observability layer design

Lives in `LLMObservability`.

### Required components

- `LLMLogger`
- `LLMMetricsRecorder`
- `LLMTraceContext`
- `ExecutionTrace`
- `LatencyMetrics`
- `TokenMetrics`
- `ModelLoadMetrics`
- `FallbackEvent`

### Must record

- cold start vs warm start
- time to first token
- total latency
- tokens per second
- model load time
- install/compile time
- fallback reason
- cancellation reason
- tool invocation count
- structured validation failures

### Rules

- logging must be privacy-aware
- logs must avoid raw secrets or sensitive data by default
- metrics must be backend-neutral at public layer

---

## 20. Model lifecycle layer design

Lives in `LLMModelLifecycle`.

This must be a separate subsystem.

### Required primary components

- `DefaultModelCatalog`
- `ManifestLoader`
- `ModelManifest`
- `ModelInstallCoordinator`
- `ModelDownloader`
- `ModelIntegrityVerifier`
- `ModelCompiler`
- `ModelCacheCoordinator`
- `WarmupManager`
- `EvictionPolicy`
- `InstallStateMachine`

### Install state machine

Use explicit states:

- `notInstalled`
- `downloading`
- `downloaded`
- `verifying`
- `compiling`
- `ready`
- `warming`
- `active`
- `failed`
- `evicted`

### Responsibilities

- fetch model manifests
- install models
- verify integrity
- compile if required
- track installed state
- warm and unload models
- reclaim disk space according to policy

### Rules

- lifecycle must not depend on chat UI
- lifecycle must not contain provider-specific inference logic
- lifecycle may delegate provider-specific compile/load steps behind backend extension points

---

## 21. Storage layer design

Lives in `LLMStorage`.

### Required components

- `FileSystemLayout`
- `ModelFileStore`
- `ManifestStore`
- `SessionFileStore`
- `AtomicWriteCoordinator`
- `StorageQuotaPolicy`

### Responsibilities

- file layout conventions
- atomic writes
- storage cleanup
- persistence helpers

### Rules

- storage must be backend-neutral
- no business logic here

---

## 22. Device layer design

Lives in `LLMDevice`.

### Required components

- `DeviceProfile`
- `MemoryPressureMonitor`
- `ThermalStateMonitor`
- `PowerStateProvider`
- `DiskSpaceProvider`
- `RuntimeSuitabilityEvaluator`

### Responsibilities

- expose current device constraints
- estimate whether model execution is suitable
- support policy-based routing

### Rules

- do not mix routing decisions here
- device layer only exposes facts and derived suitability helpers

---

## 23. Networking layer design

Lives in `LLMNetworking`.

### Required components

- `HTTPClient`
- `HTTPRequest`
- `HTTPResponse`
- `RetryPolicy`
- `ResumableDownloadClient`
- `SSEStreamClient`
- `AuthProvider`

### Responsibilities

- generic networking for remote providers and model downloads
- retries
- streaming transport
- resumable downloads

### Rules

- keep provider-agnostic
- no model semantics here

---

## 24. Backend adapter modules

Each backend must have a very narrow responsibility.

### 24.1 Foundation Models backend

Module: `LLMBackendFoundationModels`

#### Required components

- `FoundationModelsBackend`
- `FoundationModelsAvailabilityService`
- `FoundationModelsSessionAdapter`
- `FoundationModelsToolBridge`
- `FoundationModelsStructuredOutputBridge`
- `FoundationModelsRequestMapper`
- `FoundationModelsResponseMapper`

#### Responsibilities

- adapt Apple Foundation Models to generic contracts
- map generic chat/generation requests into provider requests
- map streaming events back into generic event types
- bridge provider-native sessions internally
- expose only generic types outward

#### Rules

- all Apple-specific framework calls stay here
- no leakage of provider-native request/response/session types
- use availability checks and feature gating

### 24.2 Core ML backend

Module: `LLMBackendCoreML`

#### Required components

- `CoreMLBackend`
- `CoreMLModelLoader`
- `CoreMLGenerationEngine`
- `CoreMLTokenizerAdapter`
- `CoreMLContextWindowManager`
- `CoreMLWarmupSupport`

#### Responsibilities

- execute supported local models through Core ML pipeline
- manage tokenizer/runtime bridge as needed
- support model load and warmup hooks

#### Rules

- do not hardcode one model architecture only
- isolate tokenizer/model-specific utilities behind internal adapters

### 24.3 MLX backend

Module: `LLMBackendMLX`

#### Required components

- `MLXBackend`
- `MLXModelLoader`
- `MLXGenerationEngine`
- `MLXTokenizerAdapter`
- `MLXChatEngine`

#### Responsibilities

- support local open models such as Qwen/Gemma through MLX-based runtime path
- expose generic backend interface

#### Rules

- keep MLX-specific implementation isolated
- document which model families and variants are supported

### 24.4 Remote backend

Module: `LLMBackendRemote`

#### Required components

- `RemoteBackend`
- `RemoteProviderDescriptor`
- `RemoteRequestMapper`
- `RemoteResponseMapper`
- `RemoteSSEBridge`
- `RemoteErrorMapper`
- `OpenAICompatibleTransportAdapter`

#### Responsibilities

- support hosted providers
- support streaming via SSE or equivalent transport
- normalize provider responses to generic types

#### Rules

- no provider-specific leakage outside this module
- design for multiple providers

### 24.5 Future backends

- `LLMBackendExecuTorch`
- `LLMBackendONNXRuntime`

Initially may be placeholders with docs, minimal protocol conformance stubs, and tests marking unsupported status.

---

## 25. Model families and support strategy

The architecture must explicitly support model families independently of backends.

### Initial target support matrix philosophy

- Apple Foundation Models via `foundationModels`
- Qwen via `mlx`, possibly `coreML`, optionally remote
- Gemma via `mlx`, possibly `coreML`, optionally remote
- future families without redesign

### Design rule

Family support must be described through `ModelDescriptor` metadata, not through hardcoded app logic.

Examples:

- `Qwen3-4B-Instruct-MLX-4bit`
- `Gemma-3-4B-It-MLX-4bit`
- `Apple-Foundation-Default`
- `Qwen-Remote-Large`

---

## 26. UI layer design

UI must be reusable but optional.

### 26.1 Chat UI module

Module: `LLMUIChat`

#### Required components

- `ChatScreen`
- `ChatViewModel`
- `MessageListView`
- `MessageBubbleView`
- `ComposerView`
- `TypingIndicatorView`
- `ToolCallCardView`
- `StreamingTextRenderer`
- `ChatSessionSidebarView` or equivalent optional list component
- `ChatStyle`
- `ChatTheme`
- `ChatUIState`
- `ComposerState`

#### Responsibilities

- reusable chat experience
- streaming token rendering
- tool invocation visualization
- error/retry UX
- model status display
- optionally show active model/backend badge in debug mode

#### Rules

- UI must not own inference logic
- UI must depend on public services/interfaces only
- keep styles and theme overridable

### 26.2 Downloads UI module

Module: `LLMUIDownloads`

#### Required components

- `ModelDownloadsScreen`
- `ModelRowView`
- `ModelInstallProgressView`
- `StorageUsageView`
- `WarmupStatusView`

#### Responsibilities

- show install progress
- show installed model states
- allow manual install/remove if app wants that UI

### 26.3 Prompt UI helpers

Module: `LLMUIPrompts`

#### Required components

- `PromptPresetPicker`
- `SystemPromptEditor`
- `PromptDebugView`

#### Responsibilities

- optional debugging and configuration UI

---

## 27. UI architectural rules

### State management

Use lightweight state and modern SwiftUI-friendly patterns.

Preferred:

- `@Observable` view models
- immutable view state snapshots where practical
- async actions
- unidirectional data flow

### UI boundaries

- views are renderers
- view models coordinate UI state only
- services remain in runtime/orchestrator modules
- avoid business logic in views

### Reusability

- chat UI must be themeable
- message cell rendering must support markdown/text/tool/system content states
- UI must support streaming and cancellation cleanly

---

## 28. Naming conventions

### File naming

Use one main type per file.

Examples:

- `ExecutionPlanner.swift`
- `CapabilityRouter.swift`
- `ModelDescriptor.swift`
- `ChatViewModel.swift`

### Protocol naming

Prefer noun-based protocols when representing service role.

Examples:

- `ChatService`
- `ModelCatalog`
- `SessionStore`
- `ToolRegistry`

### Concrete implementations

Use explicit names.

Examples:

- `DefaultChatService`
- `DefaultModelCatalog`
- `FoundationModelsBackend`
- `RemoteBackend`

### Anti-patterns

Avoid names like:

- `Manager`
- `Helper`
- `Util`
- `Common`
- `Misc`
- `ServiceImpl`

unless the name is narrowly justified.

---

## 29. Concurrency rules

### Mandatory rules

- shared mutable state must be actor-isolated or otherwise clearly isolated
- public async types crossing concurrency boundaries should be `Sendable`
- streaming uses `AsyncThrowingStream`
- avoid callback pyramids

### Recommended actors

- `ModelInstallCoordinator`
- `BackendRegistry` if mutable
- `SessionPersistenceCoordinator`
- `WarmupManager`
- `ToolExecutionCoordinator` if shared registry access/state exists

### Avoid

- hidden main-thread assumptions
- ad-hoc dispatch queues everywhere
- thread-unsafe caches

---

## 30. Error handling rules

### Principles

- use typed domain errors
- map provider-specific errors inside backend modules
- preserve user-actionable failure reasons when useful
- avoid stringly typed error surfaces in public API

### Logging

- log error category
- log correlation/trace IDs
- redact prompt contents by default unless explicitly debug-enabled

---

## 31. Testing strategy

Use `swift-testing` for new tests by default. XCTest may remain only where required.

### Required test layers

#### Contract tests
For:

- backend protocol conformance behavior
- structured output validation behavior
- tool execution loop behavior
- lifecycle state transitions

#### Unit tests
For:

- `ExecutionPlanner`
- `CapabilityRouter`
- `FallbackCoordinator`
- `PromptAssembler`
- `TranscriptCompactor`
- `ModelInstallCoordinator`
- `ModelIntegrityVerifier`
- `RuntimeSuitabilityEvaluator`

#### Integration tests
For:

- orchestrator + fake backends
- orchestrator + remote transport stub
- orchestrator + session store
- UI + fake chat service

#### Snapshot tests
Optional for:

- chat bubbles
- tool result cards
- download progress UI states

### Test fixtures to create

- `FakeModelBackend`
- `FakeSessionStore`
- `FakeToolRegistry`
- `FakeModelCatalog`
- `FakeModelInstaller`
- `FakeMetricsRecorder`
- `FakeAvailabilityService`

---

## 32. Performance rules

The package must be efficient and resource-aware.

### Required performance principles

- minimize cold-start work
- lazy-load heavy backends
- avoid model load unless actually needed
- warm up only when policy says it is beneficial
- support cancellation early
- never rebuild prompts/transcripts more than necessary

### Metrics to surface

- time to first token
- total completion time
- warmup duration
- model load duration
- tokens per second
- install size
- memory warning incidents

---

## 33. Security and privacy rules

### Mandatory principles

- prompts and outputs are user data
- model downloads must support integrity verification
- secrets for remote providers must not be logged
- filesystem layout must avoid accidental exposure
- debug logging must be explicitly gated

### Security-related components to add

- `ModelIntegrityVerifier`
- `LoggingRedactionPolicy`
- `SecretProvider` for remote auth if needed

---

## 34. Implementation phases

The agent must work in phases.

### Phase 0 — Scaffolding and architecture only

Deliverables:

- root docs
- ADRs
- package target definitions
- empty target entry files
- per-module docs skeletons
- dependency rule docs
- placeholders for public APIs

No real inference implementation yet.

### Phase 1 — Core runtime contracts

Deliverables:

- `LLMCore` types
- `LLMProtocols`
- `LLMSessions`
- `LLMPrompting`
- `LLMTools`
- `LLMSafety`
- `LLMObservability`
- tests for core contracts

### Phase 2 — Orchestration

Deliverables:

- `DefaultChatService`
- `DefaultGenerationService`
- `ExecutionPlanner`
- `CapabilityRouter`
- `FallbackCoordinator`
- fake backend integration tests

### Phase 3 — Lifecycle and storage

Deliverables:

- catalog
- installer
- downloader abstractions
- storage layout
- install state machine
- warmup and eviction policies

### Phase 4 — Initial backends

Deliverables:

- Foundation Models backend
- Core ML backend skeleton
- MLX backend skeleton
- remote backend
- backend-specific request/response mappers

### Phase 5 — UI

Deliverables:

- chat UI module
- downloads UI module
- prompt debug UI module
- fake/demo app surface or preview scaffolding if desired

### Phase 6 — hardening

Deliverables:

- observability polish
- safety hooks
- richer tests
- performance review
- documentation cleanup

---

## 35. Definition of done for the initial architecture pass

The initial architecture pass is complete only if:

- every target exists
- every target has docs
- every target has explicit responsibility boundaries
- dependency directions are encoded and respected
- core protocols and types are defined
- orchestration skeleton exists
- lifecycle skeleton exists
- backend skeletons exist
- UI skeleton exists
- tests compile for the core modules
- no forbidden dependency leaks exist

---

## 36. Strict implementation instructions for the agent

Follow these instructions exactly.

### Step 1
Create the package tree and all targets first.

### Step 2
Create all root docs and all per-module docs.

### Step 3
Write ADRs before detailed implementation.

### Step 4
Create public core contracts and compile-safe skeletons.

### Step 5
Implement only enough internal code to establish boundaries and testability.

### Step 6
Prefer protocol-driven seams and small concrete types.

### Step 7
Do not introduce third-party dependencies without documenting why they are needed and why native Apple frameworks are insufficient.

### Step 8
Use one source of truth for each concern. Do not duplicate model state, session state, or install state across modules.

### Step 9
When uncertain where logic belongs, choose the lower-level neutral module only if the logic is truly backend-neutral. Otherwise keep it in the backend adapter or orchestrator.

### Step 10
Every public type must have a clear reason to be public.

---

## 37. Explicit anti-sprawl rules

The architecture must not sprawl.

### Therefore

- no god objects
- no vague "shared" module
- no dumping cross-cutting utilities into random places
- no business logic in views
- no provider-specific logic in orchestration
- no storage logic in UI
- no session logic duplicated in backends
- no prompt assembly scattered across unrelated modules
- no ad-hoc global caches

---

## 38. Suggested initial file set per key module

### LLMCore

Create at minimum:

- `ModelID.swift`
- `ModelFamily.swift`
- `BackendKind.swift`
- `ModelCapability.swift`
- `ModelDescriptor.swift`
- `MessageRole.swift`
- `MessageContent.swift`
- `ChatMessage.swift`
- `ChatRequest.swift`
- `GenerationRequest.swift`
- `ChatEvent.swift`
- `GenerationEvent.swift`
- `ChatResult.swift`
- `GenerationResult.swift`
- `TokenUsage.swift`
- `LLMError.swift`

### LLMProtocols

Create at minimum:

- `ChatService.swift`
- `GenerationService.swift`
- `StructuredGenerationService.swift`
- `EmbeddingService.swift`
- `ModelBackend.swift`
- `ModelCatalog.swift`
- `ModelInstaller.swift`
- `SessionStore.swift`
- `LLMTool.swift`
- `ToolRegistry.swift`
- `InputPolicyEvaluator.swift`
- `OutputPolicyEvaluator.swift`

### LLMOrchestrator

Create at minimum:

- `DefaultChatService.swift`
- `DefaultGenerationService.swift`
- `ExecutionPlanner.swift`
- `CapabilityRouter.swift`
- `FallbackCoordinator.swift`
- `BackendRegistry.swift`
- `RequestNormalizer.swift`
- `ResponseAssembler.swift`
- `ToolExecutionCoordinator.swift`
- `StructuredOutputCoordinator.swift`

### LLMSessions

Create at minimum:

- `SessionID.swift`
- `ChatSession.swift`
- `SessionTranscript.swift`
- `TranscriptCompactor.swift`
- `SessionPersistenceCoordinator.swift`

### LLMPrompting

Create at minimum:

- `PromptTemplate.swift`
- `PromptFragment.swift`
- `PromptRegistry.swift`
- `PromptAssembler.swift`
- `PromptDebugSnapshot.swift`

### LLMTools

Create at minimum:

- `ToolDefinition.swift`
- `ToolSchema.swift`
- `ToolArguments.swift`
- `ToolExecutionContext.swift`
- `ToolResult.swift`
- `DefaultToolRegistry.swift`

### LLMSafety

Create at minimum:

- `SafetyDecision.swift`
- `SafetyReason.swift`
- `SafetyInputRequest.swift`
- `SafetyOutputRequest.swift`
- `CompositeInputPolicyEvaluator.swift`
- `CompositeOutputPolicyEvaluator.swift`
- `PIIRedactor.swift`

### LLMObservability

Create at minimum:

- `LLMLogger.swift`
- `LLMMetricsRecorder.swift`
- `LLMTraceContext.swift`
- `ExecutionTrace.swift`
- `LatencyMetrics.swift`
- `TokenMetrics.swift`
- `FallbackEvent.swift`

### LLMModelLifecycle

Create at minimum:

- `ModelManifest.swift`
- `DefaultModelCatalog.swift`
- `ManifestLoader.swift`
- `ModelInstallCoordinator.swift`
- `ModelDownloader.swift`
- `ModelIntegrityVerifier.swift`
- `ModelCompiler.swift`
- `ModelCacheCoordinator.swift`
- `WarmupManager.swift`
- `InstallStateMachine.swift`

### LLMStorage

Create at minimum:

- `FileSystemLayout.swift`
- `ModelFileStore.swift`
- `ManifestStore.swift`
- `SessionFileStore.swift`
- `AtomicWriteCoordinator.swift`
- `StorageQuotaPolicy.swift`

### LLMDevice

Create at minimum:

- `DeviceProfile.swift`
- `MemoryPressureMonitor.swift`
- `ThermalStateMonitor.swift`
- `PowerStateProvider.swift`
- `DiskSpaceProvider.swift`
- `RuntimeSuitabilityEvaluator.swift`

### LLMNetworking

Create at minimum:

- `HTTPClient.swift`
- `HTTPRequest.swift`
- `HTTPResponse.swift`
- `RetryPolicy.swift`
- `ResumableDownloadClient.swift`
- `SSEStreamClient.swift`
- `AuthProvider.swift`

### FoundationModels backend

Create at minimum:

- `FoundationModelsBackend.swift`
- `FoundationModelsAvailabilityService.swift`
- `FoundationModelsSessionAdapter.swift`
- `FoundationModelsToolBridge.swift`
- `FoundationModelsStructuredOutputBridge.swift`
- `FoundationModelsRequestMapper.swift`
- `FoundationModelsResponseMapper.swift`

### CoreML backend

Create at minimum:

- `CoreMLBackend.swift`
- `CoreMLModelLoader.swift`
- `CoreMLGenerationEngine.swift`
- `CoreMLTokenizerAdapter.swift`
- `CoreMLWarmupSupport.swift`

### MLX backend

Create at minimum:

- `MLXBackend.swift`
- `MLXModelLoader.swift`
- `MLXGenerationEngine.swift`
- `MLXTokenizerAdapter.swift`
- `MLXChatEngine.swift`

### Remote backend

Create at minimum:

- `RemoteBackend.swift`
- `RemoteProviderDescriptor.swift`
- `RemoteRequestMapper.swift`
- `RemoteResponseMapper.swift`
- `RemoteSSEBridge.swift`
- `RemoteErrorMapper.swift`
- `OpenAICompatibleTransportAdapter.swift`

### Chat UI

Create at minimum:

- `ChatScreen.swift`
- `ChatViewModel.swift`
- `MessageListView.swift`
- `MessageBubbleView.swift`
- `ComposerView.swift`
- `TypingIndicatorView.swift`
- `ToolCallCardView.swift`
- `StreamingTextRenderer.swift`
- `ChatStyle.swift`
- `ChatTheme.swift`
- `ChatUIState.swift`
- `ComposerState.swift`

### Downloads UI

Create at minimum:

- `ModelDownloadsScreen.swift`
- `ModelRowView.swift`
- `ModelInstallProgressView.swift`
- `StorageUsageView.swift`
- `WarmupStatusView.swift`

---

## 39. Guidance on latest-SDK usage

The implementation should prefer the latest stable Apple platform capabilities, but keep them isolated behind adapters so that the package remains structurally clean.

### Current direction to prefer

- modern Swift concurrency first
- `swift-testing` for new tests
- Apple Foundation Models backend isolated in its own target
- reusable SwiftUI components isolated in optional UI modules
- local model support abstracted away from app code

### Important compatibility rule

If a framework requires a newer OS than the package baseline, keep that support behind a backend target and gate it with availability.

---

## 40. Final instruction to the implementation agent

Implement this package as a **modular AI runtime platform**, not as a feature prototype.

The first successful result is not "the chat works".
The first successful result is:

- the architecture is explicit
- layers are enforced
- responsibilities are documented
- the package can grow without redesign
- model families like Qwen and Gemma can be attached cleanly through backend adapters
- Apple Foundation Models support remains isolated and optional
- chat UI remains reusable and does not contaminate the runtime core

Start with scaffolding, docs, ADRs, and contracts. Only then proceed to implementation.
