# Architecture Overview

LLMKit is structured as a layered Swift package. `LLMCore` owns pure domain types. `LLMProtocols` owns service and adapter contracts. Coordination modules shape state, prompts, tools, safety, observability, storage, device signals, networking, and lifecycle. `LLMOrchestrator` composes those capabilities. Backend adapters isolate provider or runtime specifics. UI modules are optional and backend-agnostic.
