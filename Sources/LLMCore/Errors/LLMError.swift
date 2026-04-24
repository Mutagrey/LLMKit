import Foundation

public enum LLMError: Error, Equatable, Sendable {
    case unavailable
    case unsupportedCapabilities(Set<ModelCapability>)
    case modelNotInstalled(ModelID)
    case downloadFailed(String)
    case verificationFailed(String)
    case compilationFailed
    case executionFailed(String)
    case toolExecutionFailed(String)
    case invalidStructuredOutput(String)
    case cancelled
}

public enum BackendError: Error, Equatable, Sendable {
    case unavailable(BackendKind)
    case mappingFailed(String)
    case providerFailed(String)
}

public enum ValidationError: Error, Equatable, Sendable {
    case missingRequiredValue(String)
    case invalidValue(String)
}

public enum StorageError: Error, Equatable, Sendable {
    case notFound(String)
    case writeFailed(String)
    case readFailed(String)
}
