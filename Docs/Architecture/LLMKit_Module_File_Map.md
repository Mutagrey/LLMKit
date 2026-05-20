# LLMKit Module File Map

## Purpose

This file is the concrete file-level companion to the master architecture blueprint and package scaffold.

The goal is to eliminate ambiguity for the coding agent by specifying:

- which initial files should exist in each module
- which types belong in those files
- which files are phase-1 placeholders versus early implementation files
- which files must remain small and focused
- which modules must avoid owning logic that belongs elsewhere

This file map is intentionally opinionated. The agent should follow it unless there is a strong architectural reason not to, and any meaningful deviation must be documented in an ADR.

---

## Global file rules

1. One primary type per file when practical.
2. File name should match the primary type.
3. Avoid catch-all files like:
   - `Helpers.swift`
   - `Extensions.swift`
   - `Utils.swift`
   - `Managers.swift`
4. If shared helpers are truly needed, they must be narrowly named by domain concern.
5. Keep cross-module extensions to a minimum.
6. Public API files should be especially small and easy to scan.
7. If a file grows beyond a few hundred lines, the agent should consider splitting by responsibility.

---

## Root package files

```text
Package.swift
README.md
CHANGELOG.md
LICENSE
.gitignore
```

### Root docs
```text
Docs/
├─ Architecture/
│  ├─ Overview.md
│  ├─ DependencyGraph.md
│  ├─ LayerRules.md
│  ├─ CapabilityRouting.md
│  ├─ ModelLifecycle.md
│  ├─ UIArchitecture.md
│  └─ TestingStrategy.md
├─ ADR/
│  ├─ ADR-001-Modularization.md
│  ├─ ADR-002-CapabilityDrivenRouting.md
│  ├─ ADR-003-SessionOwnership.md
│  ├─ ADR-004-ModelLifecycleSeparation.md
│  ├─ ADR-005-UIIsolation.md
│  ├─ ADR-006-RemoteProviderAbstraction.md
│  └─ ADR-007-MLXBackendStatus.md
└─ Agent/
   ├─ AgentExecutionPlan.md
   ├─ WorkRules.md
   ├─ DoneDefinition.md
   └─ ProgressTemplate.md
```

---

# Sources/LLMCore

## Purpose
Pure domain types, identifiers, enums, stable shared DTOs, and error primitives.

## Initial files

```text
Sources/LLMCore/
├─ Docs/
│  ├─ Overview.md
│  ├─ Responsibilities.md
│  ├─ PublicAPI.md
│  ├─ DependencyRules.md
│  └─ TODO.md
├─ Model/
│  ├─ ModelID.swift
│  ├─ ModelDescriptor.swift
│  ├─ ModelFamily.swift
│  ├─ BackendKind.swift
│  ├─ ModelCapability.swift
│  ├─ Quantization.swift
│  ├─ ModelSource.swift
│  ├─ ModelLicense.swift
│  └─ ModelAvailability.swift
├─ Requests/
│  ├─ GenerationRequest.swift
│  ├─ ChatRequest.swift
│  ├─ StructuredRequest.swift
│  ├─ EmbeddingRequest.swift
│  ├─ ToolExecutionRequest.swift
│  └─ ExecutionRequirements.swift
├─ Responses/
│  ├─ GenerationResult.swift
│  ├─ StructuredGenerationResult.swift
│  ├─ EmbeddingResult.swift
│  ├─ UsageMetrics.swift
│  └─ TokenUsage.swift
├─ Streaming/
│  ├─ GenerationEvent.swift
│  ├─ ChatEvent.swift
│  ├─ ToolEvent.swift
│  └─ StreamFinishReason.swift
├─ Chat/
│  ├─ ChatMessage.swift
│  ├─ ChatRole.swift
│  ├─ ConversationTurn.swift
│  └─ AttachmentReference.swift
├─ Sessions/
│  ├─ SessionID.swift
│  ├─ SessionDescriptor.swift
│  ├─ SessionSummary.swift
│  └─ SessionState.swift
├─ Tools/
│  ├─ ToolDefinition.swift
│  ├─ ToolSchema.swift
│  ├─ ToolInvocation.swift
│  ├─ ToolResult.swift
│  └─ ToolPermission.swift
├─ Lifecycle/
│  ├─ DownloadState.swift
│  ├─ InstallState.swift
│  ├─ WarmupState.swift
│  └─ EvictionReason.swift
├─ Policy/
│  ├─ QualityTier.swift
│  ├─ LatencyPreference.swift
│  ├─ PrivacyMode.swift
│  ├─ SafetyAction.swift
│  └─ ExecutionBudget.swift
└─ Errors/
│  ├─ LLMError.swift
│  ├─ BackendError.swift
│  ├─ ValidationError.swift
│  └─ StorageError.swift
```

### Notes
- `LLMCore` must not import backend frameworks.
- `GenerationRequest` and `ChatRequest` should remain generic and backend-neutral.
- Avoid separate request types per backend.

---

# Sources/LLMProtocols

## Purpose
Stable contracts between high-level orchestration and concrete implementations.

## Initial files

```text
Sources/LLMProtocols/
├─ Docs/
│  ├─ Overview.md
│  ├─ Responsibilities.md
│  ├─ PublicAPI.md
│  ├─ DependencyRules.md
│  └─ TODO.md
├─ Services/
│  ├─ LanguageGenerationService.swift
│  ├─ ChatService.swift
│  ├─ StructuredGenerationService.swift
│  ├─ EmbeddingService.swift
│  ├─ SessionService.swift
│  ├─ ModelLifecycleService.swift
│  └─ ToolService.swift
├─ Backends/
│  ├─ ModelBackend.swift
│  ├─ LoadedModelHandle.swift
│  ├─ BackendGenerationRequest.swift
│  ├─ BackendGenerationEvent.swift
│  ├─ BackendAvailability.swift
│  └─ BackendCapabilities.swift
├─ Catalog/
│  ├─ ModelCatalogProviding.swift
│  ├─ ModelManifestProviding.swift
│  └─ InstalledModelProviding.swift
├─ Storage/
│  ├─ SessionStore.swift
│  ├─ ManifestStore.swift
│  ├─ BinaryAssetStore.swift
│  └─ CacheStore.swift
├─ Tools/
│  ├─ ToolExecutor.swift
│  ├─ ToolRegistryProviding.swift
│  └─ ToolArgumentValidator.swift
├─ Observability/
│  ├─ MetricsSink.swift
│  ├─ LoggerSink.swift
│  └─ TraceEmitter.swift
└─ Safety/
│  ├─ SafetyPolicyEvaluating.swift
│  ├─ InputGuarding.swift
│  ├─ OutputGuarding.swift
│  └─ ToolPermissionEvaluating.swift
```

---

# Sources/LLMSessions

## Purpose
Owns session state, transcript control, context window shaping, and session persistence coordination.

## Initial files

```text
Sources/LLMSessions/
├─ Docs/
├─ SessionCoordinator.swift
├─ SessionFactory.swift
├─ SessionStoreAdapter.swift
├─ ConversationTranscript.swift
├─ TranscriptWindow.swift
├─ SessionSnapshot.swift
├─ SessionRestorer.swift
├─ SessionCompressor.swift
├─ SessionTruncationPolicy.swift
├─ ContextWindowManager.swift
└─ SessionMutation.swift
```

### Notes
- `SessionCoordinator` should not choose the model.
- `SessionCompressor` should expose extension points for summarization.

---

# Sources/LLMPrompting

## Purpose
Prompt assembly, template versioning, task presets, and truncation-friendly prompt shaping.

## Initial files

```text
Sources/LLMPrompting/
├─ Docs/
├─ PromptTemplate.swift
├─ PromptTemplateID.swift
├─ PromptVersion.swift
├─ PromptRegistry.swift
├─ PromptAssembler.swift
├─ PromptFragment.swift
├─ PromptContext.swift
├─ SystemPromptProvider.swift
├─ DeveloperPromptProvider.swift
├─ TaskPromptPreset.swift
├─ PromptDebugSnapshot.swift
└─ PromptLocalization.swift
```

### Notes
- Keep prompt templates declarative.
- Avoid embedding app feature logic here.

---

# Sources/LLMTools

## Purpose
Backend-neutral tool calling abstractions and execution coordination.

## Initial files

```text
Sources/LLMTools/
├─ Docs/
├─ LLMTool.swift
├─ AnyLLMTool.swift
├─ ToolRegistry.swift
├─ ToolCatalog.swift
├─ ToolSchemaEncoder.swift
├─ ToolInvocationDecoder.swift
├─ ToolExecutionCoordinator.swift
├─ ToolResultNormalizer.swift
├─ ToolExecutionContext.swift
└─ ToolExecutionPolicy.swift
```

### Notes
- Tool implementations from host apps should be pluggable.
- Avoid hardcoding Apple-only or remote-only tool workflows.

---

# Sources/LLMSafety

## Purpose
Policy hooks for redaction, output validation, budget limits, and tool permissions.

## Initial files

```text
Sources/LLMSafety/
├─ Docs/
├─ SafetyPolicy.swift
├─ InputGuard.swift
├─ OutputGuard.swift
├─ PIIRedactor.swift
├─ TokenBudgetPolicy.swift
├─ ToolPermissionPolicy.swift
├─ PrivacyModeEvaluator.swift
└─ SafetyDecision.swift
```

---

# Sources/LLMObservability

## Purpose
Structured telemetry, logs, debug traces, and performance snapshots.

## Initial files

```text
Sources/LLMObservability/
├─ Docs/
├─ TelemetryEvent.swift
├─ GenerationTrace.swift
├─ MetricsCollector.swift
├─ LatencyTracker.swift
├─ ThroughputTracker.swift
├─ FallbackTrace.swift
├─ DebugSnapshotEmitter.swift
├─ ObservabilityConfiguration.swift
└─ LoggingPolicy.swift
```

### Notes
- Keep sinks swappable.
- Avoid direct OSLog lock-in in public-facing abstractions.

---

# Sources/LLMStorage

## Purpose
Persistence primitives, not business policy.

## Initial files

```text
Sources/LLMStorage/
├─ Docs/
├─ FileStore.swift
├─ ManifestFileStore.swift
├─ SessionFileStore.swift
├─ CacheFileStore.swift
├─ SecureMetadataStore.swift
├─ StoragePaths.swift
├─ AtomicWriteCoordinator.swift
└─ DiskUsageSnapshot.swift
```

---

# Sources/LLMDeviceProfiling

## Purpose
Collect routing-relevant device/runtime constraints.

## Initial files

```text
Sources/LLMDeviceProfiling/
├─ Docs/
├─ DeviceProfile.swift
├─ DeviceClass.swift
├─ RuntimeConstraints.swift
├─ MemoryPressureSnapshot.swift
├─ ThermalStateSnapshot.swift
├─ BatteryStateSnapshot.swift
├─ ExecutionBudgetSnapshot.swift
└─ DeviceProfileCollector.swift
```

---

# Sources/LLMNetworking

## Purpose
Remote HTTP/SSE transport only.

## Initial files

```text
Sources/LLMNetworking/
├─ Docs/
├─ HTTPRequestBuilder.swift
├─ HTTPTransport.swift
├─ StreamingHTTPClient.swift
├─ SSEParser.swift
├─ RetryPolicy.swift
├─ AuthHeaderProvider.swift
├─ RemoteEndpoint.swift
└─ RemoteTransportError.swift
```

---

# Sources/LLMModelLifecycle

## Purpose
Model discovery, install, verification, warmup, update, eviction.

## Initial files

```text
Sources/LLMModelLifecycle/
├─ Docs/
├─ ModelCatalog.swift
├─ ModelManifest.swift
├─ ModelManifestSignature.swift
├─ ModelInstaller.swift
├─ ModelDownloader.swift
├─ DownloadCoordinator.swift
├─ ModelVerifier.swift
├─ ModelCompiler.swift
├─ ModelWarmupManager.swift
├─ ModelEvictionManager.swift
├─ InstalledModelIndex.swift
├─ InstallStateMachine.swift
├─ InstallProgress.swift
└─ StorageQuotaPolicy.swift
```

### Notes
- Keep the install state machine explicit.
- This module must not own prompt execution.

---

# Sources/LLMOrchestrator

## Purpose
Main runtime brain: routing, planning, fallback, coordination.

## Initial files

```text
Sources/LLMOrchestrator/
├─ Docs/
├─ LLMKitContainer.swift
├─ LLMKitFactory.swift
├─ InferenceCoordinator.swift
├─ ModelRouter.swift
├─ ExecutionPlanner.swift
├─ ExecutionPlan.swift
├─ CapabilityMatcher.swift
├─ FallbackCoordinator.swift
├─ RequestNormalizer.swift
├─ RequestContext.swift
├─ ExecutionContextBuilder.swift
├─ GenerationPipeline.swift
├─ StructuredGenerationPipeline.swift
├─ ChatPipeline.swift
├─ ToolCallingPipeline.swift
├─ DefaultLanguageGenerationService.swift
├─ DefaultChatService.swift
├─ DefaultStructuredGenerationService.swift
└─ DefaultEmbeddingService.swift
```

### Notes
- `LLMKitContainer` is the main app-facing façade.
- Pipelines should be composed, not giant god-objects.

---

# Sources/LLMBackendFoundationModels

## Purpose
Apple Foundation Models backend adapter only.

## Initial files

```text
Sources/LLMBackendFoundationModels/
├─ Docs/
├─ FoundationModelsBackend.swift
├─ FoundationModelsAvailabilityService.swift
├─ FoundationModelsRequestMapper.swift
├─ FoundationModelsResponseMapper.swift
├─ FoundationModelsSessionAdapter.swift
├─ FoundationModelsToolBridge.swift
├─ FoundationModelsStructuredOutputBridge.swift
└─ FoundationModelsErrorMapper.swift
```

### Notes
- Keep all Apple framework-specific imports confined here.
- Availability checks must be isolated in dedicated types.

---

# Sources/LLMBackendCoreML

## Purpose
Core ML local inference backend.

## Initial files

```text
Sources/LLMBackendCoreML/
├─ Docs/
├─ CoreMLBackend.swift
├─ CoreMLModelLoader.swift
├─ CoreMLRuntimeSession.swift
├─ CoreMLRequestMapper.swift
├─ CoreMLResponseMapper.swift
├─ CoreMLModelCompatibilityChecker.swift
├─ CoreMLWarmupStrategy.swift
└─ CoreMLErrorMapper.swift
```

### Notes
- Separate loading, compatibility checking, and execution.

---

# Sources/LLMBackendMLX

## Purpose
Experimental MLX backend for local open-weight models such as Qwen and Gemma families.

## Initial files

```text
Sources/LLMBackendMLX/
├─ Docs/
├─ MLXBackend.swift
├─ MLXModelLoader.swift
├─ MLXRuntimeSession.swift
├─ MLXRequestMapper.swift
├─ MLXResponseMapper.swift
├─ MLXModelSupportMatrix.swift
├─ MLXQuantizationSupport.swift
└─ MLXErrorMapper.swift
```

### Notes
- Support matrix must be explicit by family/version.
- This module should clearly document maturity and limitations.

---

# Sources/LLMBackendRemote

## Purpose
Remote provider abstraction and transport-backed inference.

## Initial files

```text
Sources/LLMBackendRemote/
├─ Docs/
├─ RemoteBackend.swift
├─ RemoteProvider.swift
├─ RemoteProviderID.swift
├─ OpenAICompatibleProvider.swift
├─ RemoteRequestMapper.swift
├─ RemoteResponseMapper.swift
├─ RemoteStreamingAdapter.swift
├─ RemoteErrorMapper.swift
└─ RemoteConfiguration.swift
```

### Notes
- Keep provider-specific DTOs hidden.
- Public surface should remain generic.

---

# Sources/LLMUIChat

## Purpose
Reusable backend-agnostic chat UI built with SwiftUI.

## Initial files

```text
Sources/LLMUIChat/
├─ Docs/
├─ ChatScreen.swift
├─ ChatViewModel.swift
├─ ChatComposerView.swift
├─ ChatComposerState.swift
├─ ChatTimelineView.swift
├─ TimelineSection.swift
├─ RenderedMessage.swift
├─ MessageBubbleView.swift
├─ StreamingMessageView.swift
├─ MessageStreamingState.swift
├─ TypingStateView.swift
├─ ToolInvocationView.swift
├─ AttachmentDraft.swift
├─ ChatInputPolicy.swift
├─ ChatTheme.swift
└─ MarkdownMessageRenderer.swift
```

### Notes
- View model should consume public services only.
- Rendering layer should not know backend details.

---

# Sources/LLMUIModels

## Purpose
Reusable UI for model catalog, installs, progress, and storage usage.

## Initial files

```text
Sources/LLMUIModels/
├─ Docs/
├─ ModelListView.swift
├─ ModelRowView.swift
├─ ModelDetailView.swift
├─ ModelInstallProgressView.swift
├─ ModelDownloadsViewModel.swift
├─ StorageUsageView.swift
├─ ModelStorageSummary.swift
└─ ModelFormatting.swift
```

---

# Sources/LLMUIStorage

## Purpose
Reusable backend-neutral storage visualization primitives for UI modules.

## Initial files

```text
Sources/LLMUIStorage/
├─ Docs/
└─ StorageUsageBarView.swift
```

---

# Tests

Each module should have a matching test target.

## Example test file map

```text
Tests/LLMCoreTests/
├─ ModelDescriptorTests.swift
├─ GenerationRequestTests.swift
├─ UsageMetricsTests.swift
└─ LLMErrorTests.swift

Tests/LLMOrchestratorTests/
├─ ModelRouterTests.swift
├─ ExecutionPlannerTests.swift
├─ FallbackCoordinatorTests.swift
├─ ChatPipelineTests.swift
└─ StructuredGenerationPipelineTests.swift

Tests/LLMBackendRemoteTests/
├─ RemoteRequestMapperTests.swift
├─ RemoteStreamingAdapterTests.swift
└─ RemoteErrorMapperTests.swift
```

The agent should start with narrow tests around public API invariants and routing logic.

---

# Phase-based file creation plan

## Phase 1: scaffold only
Create:
- all module folders
- all `Docs/`
- namespace files if needed
- no heavy implementation yet

## Phase 2: core foundation
Implement first:
- `ModelID.swift`
- `ModelDescriptor.swift`
- `ModelCapability.swift`
- `GenerationRequest.swift`
- `GenerationResult.swift`
- `GenerationEvent.swift`
- `ChatMessage.swift`
- `LLMError.swift`

Then:
- `LanguageGenerationService.swift`
- `ChatService.swift`
- `StructuredGenerationService.swift`
- `ModelBackend.swift`

## Phase 3: orchestration backbone
Implement:
- `LLMKitContainer.swift`
- `LLMKitFactory.swift`
- `ModelRouter.swift`
- `ExecutionPlanner.swift`
- `InferenceCoordinator.swift`

## Phase 4: supporting coordination
Implement:
- `SessionCoordinator.swift`
- `PromptRegistry.swift`
- `PromptAssembler.swift`
- `ToolExecutionCoordinator.swift`
- `MetricsCollector.swift`
- `ModelCatalog.swift`

## Phase 5: backend adapters
Start with:
- `FoundationModelsBackend.swift`
- `RemoteBackend.swift`

Then:
- `CoreMLBackend.swift`
- `MLXBackend.swift`

## Phase 6: UI layer
Implement only after services are stable.

---

# Explicit anti-sprawl reminders for the agent

- Do not create `Manager` files unless the name is domain-specific and justified.
- Do not create duplicate request/response mappers in high-level modules.
- Do not create backend-specific types inside `LLMCore`.
- Do not create a giant `ChatViewModel` that owns networking, persistence, and business policies.
- Do not place Markdown parsing, tool execution, and routing logic all into one UI file.
- Do not create a separate model catalog representation in every backend.
- Keep one source of truth for model descriptors.

---

# Final instruction

The agent should treat this file map as the concrete implementation skeleton.

When deciding whether to add a new file, ask:
1. Does this file have a single clear responsibility?
2. Does the type belong in this module and nowhere higher or lower?
3. Is an existing type already responsible for this concern?
4. Will this increase clarity more than it increases surface area?

If the answer is not clearly yes, do not add the file.
