# LLMDeviceProfiling Public API

Public API includes `DeviceProfile`, `RuntimeConstraints`, `DeviceProfileCollector`, and
`RuntimeConstraintsCollector`.

These types stay backend-neutral so orchestration can make routing decisions without importing provider SDKs,
UI modules, or lifecycle persistence details.
