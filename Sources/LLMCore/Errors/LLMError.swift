import Foundation

public enum LLMError: Error, Hashable, Sendable {
    case unavailable
    case unsupportedCapabilities(Set<ModelCapability>)
    case unsupportedLocale(String)
    case modelSelectionFailed(String)
    case modelNotInstalled(ModelID)
    case downloadFailed(String)
    case verificationFailed(String)
    case compilationFailed
    case executionFailed(String)
    case toolExecutionFailed(String)
    case invalidStructuredOutput(String)
    case cancelled
}

public enum BackendError: Error, Hashable, Sendable {
    case unavailable(BackendKind)
    case mappingFailed(String)
    case providerFailed(String)
}

public enum ValidationError: Error, Hashable, Sendable {
    case missingRequiredValue(String)
    case invalidValue(String)
}

public enum StorageError: Error, Hashable, Sendable {
    case notFound(String)
    case writeFailed(String)
    case readFailed(String)
}
