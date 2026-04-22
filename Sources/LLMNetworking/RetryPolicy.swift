import Foundation

public struct RetryPolicy: Hashable, Sendable {
    public let maxAttempts: Int
    public let delaySeconds: Double

    public init(maxAttempts: Int = 3, delaySeconds: Double = 0.5) {
        self.maxAttempts = maxAttempts
        self.delaySeconds = delaySeconds
    }
}

public struct AuthHeaderProvider: Sendable {
    private let headerProvider: @Sendable () -> [String: String]

    public init(headerProvider: @escaping @Sendable () -> [String: String]) {
        self.headerProvider = headerProvider
    }

    public func headers() -> [String: String] {
        headerProvider()
    }
}
