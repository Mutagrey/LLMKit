import Foundation

public struct ModelInstallInterruptionPolicy: Hashable, Sendable {
    public enum CancellationBehavior: Hashable, Sendable {
        case preserveVerifiedArtifactsForResume
        case removeAllArtifacts
    }

    public let cancellationBehavior: CancellationBehavior

    public init(cancellationBehavior: CancellationBehavior = .preserveVerifiedArtifactsForResume) {
        self.cancellationBehavior = cancellationBehavior
    }

    public static let `default` = ModelInstallInterruptionPolicy()
}
