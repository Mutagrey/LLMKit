import Foundation
import LLMCore
import LLMNetworking
import LLMObservability
import LLMProtocols

public struct RemoteProviderID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public struct RemoteConfiguration: Hashable, Sendable {
    public let providerID: RemoteProviderID
    public let baseURL: URL
    public let defaultHeaders: [String: String]

    public init(providerID: RemoteProviderID, baseURL: URL, defaultHeaders: [String: String] = [:]) {
        self.providerID = providerID
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
    }
}

public struct RemoteBackend: ModelBackend {
    public let backendKind: BackendKind = .remote
    public let configuration: RemoteConfiguration?

    public init(configuration: RemoteConfiguration? = nil) {
        self.configuration = configuration
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        descriptor.backend == backendKind ? .unsupported : .unsupported
    }

    public func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.backend == backendKind && model.capabilities.contains(capability)
    }

    public func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle {
        throw LLMError.unavailable
    }

    public func unloadModel(_ handle: LoadedModelHandle) async {}

    public func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.unavailable)
        }
    }

    public func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.unavailable)
        }
    }
}

public enum LLMBackendRemoteNamespace {}
