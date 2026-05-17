import LLMCore

struct SafetyPolicyDenied: Error, Sendable {
    let reason: String
}

enum SafetyPolicyBridge {
    static func rejectionMessage(_ reason: String) -> String {
        "Safety policy denied the request: \(reason)"
    }

    static func rejectionMessage(for error: SafetyPolicyDenied) -> String {
        rejectionMessage(error.reason)
    }

    static func reason(from action: SafetyAction) -> String? {
        guard case .deny(let reason) = action else {
            return nil
        }
        return reason
    }
}
