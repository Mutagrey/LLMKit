# Dependency Graph

Dependency direction is one-way:

```text
UI -> Orchestrator/services -> coordination modules -> LLMProtocols -> LLMCore
Backend adapters -> LLMProtocols + LLMCore
Lifecycle -> storage/observability/core/protocols
Remote backend -> networking/protocols/core
```

No module may introduce a reverse dependency to make implementation easier.
