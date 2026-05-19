import Foundation

public struct LocalRuntimeMemoryEstimate: Hashable, Sendable {
    public let modelMemoryBytes: UInt64
    public let contextMemoryBytes: UInt64
    public let workingMemoryBytes: UInt64

    public init(
        modelMemoryBytes: UInt64,
        contextMemoryBytes: UInt64 = 0,
        workingMemoryBytes: UInt64 = LocalRuntimeMemoryGuard.megabytes(256)
    ) {
        self.modelMemoryBytes = modelMemoryBytes
        self.contextMemoryBytes = contextMemoryBytes
        self.workingMemoryBytes = workingMemoryBytes
    }

    public var totalBytes: UInt64 {
        LocalRuntimeMemoryGuard.saturatedSum([
            modelMemoryBytes,
            contextMemoryBytes,
            workingMemoryBytes
        ])
    }
}

public struct LocalRuntimeMemoryDecision: Hashable, Sendable {
    public let canLoad: Bool
    public let reason: String?
    public let requiredBytes: UInt64
    public let availableProcessMemoryBytes: UInt64?
    public let safetyReserveBytes: UInt64
    public let shouldUseFallback: Bool

    public init(
        canLoad: Bool,
        reason: String?,
        requiredBytes: UInt64,
        availableProcessMemoryBytes: UInt64?,
        safetyReserveBytes: UInt64,
        shouldUseFallback: Bool
    ) {
        self.canLoad = canLoad
        self.reason = reason
        self.requiredBytes = requiredBytes
        self.availableProcessMemoryBytes = availableProcessMemoryBytes
        self.safetyReserveBytes = safetyReserveBytes
        self.shouldUseFallback = shouldUseFallback
    }
}

public struct LocalRuntimeMemoryGuard: Sendable {
    public let safetyReserveBytes: UInt64

    public init(safetyReserveBytes: UInt64 = LocalRuntimeMemoryGuard.megabytes(512)) {
        self.safetyReserveBytes = safetyReserveBytes
    }

    public func evaluate(
        estimate: LocalRuntimeMemoryEstimate,
        profile: DeviceProfile
    ) -> LocalRuntimeMemoryDecision {
        let requiredBytes = Self.saturatedSum([estimate.totalBytes, safetyReserveBytes])
        guard let availableProcessMemoryBytes = profile.availableProcessMemoryBytes else {
            return LocalRuntimeMemoryDecision(
                canLoad: true,
                reason: "Process available memory is unavailable on this platform.",
                requiredBytes: requiredBytes,
                availableProcessMemoryBytes: nil,
                safetyReserveBytes: safetyReserveBytes,
                shouldUseFallback: false
            )
        }

        guard availableProcessMemoryBytes >= requiredBytes else {
            return LocalRuntimeMemoryDecision(
                canLoad: false,
                reason: "Insufficient process memory for the selected local model and context.",
                requiredBytes: requiredBytes,
                availableProcessMemoryBytes: availableProcessMemoryBytes,
                safetyReserveBytes: safetyReserveBytes,
                shouldUseFallback: true
            )
        }

        return LocalRuntimeMemoryDecision(
            canLoad: true,
            reason: nil,
            requiredBytes: requiredBytes,
            availableProcessMemoryBytes: availableProcessMemoryBytes,
            safetyReserveBytes: safetyReserveBytes,
            shouldUseFallback: false
        )
    }

    public static func megabytes(_ value: UInt64) -> UInt64 {
        saturatedMultiply(value, 1_048_576)
    }

    static func saturatedSum(_ values: [UInt64]) -> UInt64 {
        values.reduce(0) { partialResult, value in
            let result = partialResult.addingReportingOverflow(value)
            return result.overflow ? UInt64.max : result.partialValue
        }
    }

    private static func saturatedMultiply(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }
}
