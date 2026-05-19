# LLMDeviceProfiling Public API

Public API includes `DeviceProfile`, `RuntimeConstraints`, `DeviceProfileCollector`,
`RuntimeConstraintsCollector`, `LocalRuntimeMemoryEstimate`, `LocalRuntimeMemoryDecision`, and
`LocalRuntimeMemoryGuard`.

These types stay backend-neutral so orchestration can make routing decisions without importing provider SDKs,
UI modules, or lifecycle persistence details.
