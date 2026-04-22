import LLMDeviceProfiling
import Testing

@Test func deviceProfileCollectorReturnsRuntimeFacts() {
    let profile = DeviceProfileCollector().currentProfile()

    #expect(profile.processorCount > 0)
}
