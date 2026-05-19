import LLMDeviceProfiling
import Testing

@Test func deviceProfileCollectorReturnsRuntimeFacts() {
    let profile = DeviceProfileCollector().currentProfile()

    #expect(profile.processorCount > 0)
    #expect(profile.physicalMemoryBytes > 0)
    #expect(profile.operatingSystemVersion.isEmpty == false)
}

@Test func deviceProfileIsAValueSnapshot() {
    let profile = DeviceProfile(
        operatingSystemVersion: "Test OS",
        physicalMemoryBytes: 16,
        processorCount: 8,
        availableProcessMemoryBytes: 12
    )

    #expect(profile.operatingSystemVersion == "Test OS")
    #expect(profile.physicalMemoryBytes == 16)
    #expect(profile.processorCount == 8)
    #expect(profile.availableProcessMemoryBytes == 12)
}

@Test func runtimeConstraintsDefaultToNoExtraRequirements() {
    let defaults = RuntimeConstraints()
    let constrained = RuntimeConstraints(isLowPowerPreferred: true, minimumFreeDiskGB: 4)

    #expect(defaults.isLowPowerPreferred == false)
    #expect(defaults.minimumFreeDiskGB == nil)
    #expect(constrained.isLowPowerPreferred == true)
    #expect(constrained.minimumFreeDiskGB == 4)
}

@Test func runtimeConstraintsCollectorReturnsRuntimeSnapshot() {
    let constraints = RuntimeConstraintsCollector().currentConstraints()

    if let minimumFreeDiskGB = constraints.minimumFreeDiskGB {
        #expect(minimumFreeDiskGB >= 0)
    }
}

@Test func localRuntimeMemoryGuardRejectsOversizedModel() {
    let profile = DeviceProfile(
        operatingSystemVersion: "Test OS",
        physicalMemoryBytes: LocalRuntimeMemoryGuard.megabytes(4096),
        processorCount: 8,
        availableProcessMemoryBytes: LocalRuntimeMemoryGuard.megabytes(512)
    )
    let estimate = LocalRuntimeMemoryEstimate(
        modelMemoryBytes: LocalRuntimeMemoryGuard.megabytes(400),
        contextMemoryBytes: LocalRuntimeMemoryGuard.megabytes(128),
        workingMemoryBytes: LocalRuntimeMemoryGuard.megabytes(128)
    )
    let decision = LocalRuntimeMemoryGuard(safetyReserveBytes: LocalRuntimeMemoryGuard.megabytes(128))
        .evaluate(estimate: estimate, profile: profile)

    #expect(!decision.canLoad)
    #expect(decision.shouldUseFallback)
    #expect(decision.availableProcessMemoryBytes == LocalRuntimeMemoryGuard.megabytes(512))
}

@Test func localRuntimeMemoryGuardAllowsUnknownProcessLimitWithoutClaimingProof() {
    let profile = DeviceProfile(
        operatingSystemVersion: "macOS",
        physicalMemoryBytes: LocalRuntimeMemoryGuard.megabytes(16_384),
        processorCount: 10
    )
    let estimate = LocalRuntimeMemoryEstimate(modelMemoryBytes: LocalRuntimeMemoryGuard.megabytes(1024))
    let decision = LocalRuntimeMemoryGuard().evaluate(estimate: estimate, profile: profile)

    #expect(decision.canLoad)
    #expect(decision.availableProcessMemoryBytes == nil)
    #expect(decision.reason != nil)
}
