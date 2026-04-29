import LLMCore

public struct ChatErrorPresentation: Hashable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public init(error: Error) {
        if let error = error as? LLMError {
            switch error {
            case .toolExecutionFailed(let message):
                self.init(title: "Tool Failed", message: message)
            case .executionFailed(let message):
                self.init(title: "Request Failed", message: message)
            case .cancelled:
                self.init(title: "Cancelled", message: "The request was cancelled.")
            case .unavailable:
                self.init(title: "Unavailable", message: "The selected model is currently unavailable.")
            case .unsupportedCapabilities:
                self.init(title: "Unsupported", message: "The selected model does not support this request.")
            case .unsupportedLocale(let localeIdentifier):
                self.init(title: "Unsupported Locale", message: localeIdentifier)
            case .modelSelectionFailed(let message):
                self.init(title: "Model Selection Failed", message: message)
            case .modelNotInstalled(let modelID):
                self.init(title: "Model Missing", message: "\(modelID.rawValue) is not installed.")
            case .downloadFailed(let message):
                self.init(title: "Download Failed", message: message)
            case .verificationFailed(let message):
                self.init(title: "Verification Failed", message: message)
            case .compilationFailed:
                self.init(title: "Compilation Failed", message: "Model compilation failed.")
            case .invalidStructuredOutput(let message):
                self.init(title: "Invalid Output", message: message)
            }
        } else {
            self.init(title: "Error", message: error.localizedDescription)
        }
    }
}
