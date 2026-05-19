import Foundation

public struct LLMSettingsStorageSummary: Hashable, Sendable {
    public let installedModelCount: Int?
    public let totalModelCount: Int?
    public let chatCount: Int?
    public let installedModelBytes: Int64
    public let partialArtifactBytes: Int64
    public let availableBytes: Int64?
    public let capacityBytes: Int64?

    public init(
        installedModelCount: Int? = nil,
        totalModelCount: Int? = nil,
        chatCount: Int? = nil,
        installedModelBytes: Int64,
        partialArtifactBytes: Int64,
        availableBytes: Int64? = nil,
        capacityBytes: Int64? = nil
    ) {
        self.installedModelCount = installedModelCount
        self.totalModelCount = totalModelCount
        self.chatCount = chatCount
        self.installedModelBytes = installedModelBytes
        self.partialArtifactBytes = partialArtifactBytes
        self.availableBytes = availableBytes
        self.capacityBytes = capacityBytes
    }
}
