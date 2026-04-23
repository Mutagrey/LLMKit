# LLMTools Public API

Public API includes the default registry and execution coordinator.

`DefaultToolRegistry` returns definitions sorted by name and replaces definition/executor pairs with the same tool name. `ToolExecutionCoordinator` validates required arguments before executor lookup and reports unregistered tools or missing executors through backend-neutral errors.
