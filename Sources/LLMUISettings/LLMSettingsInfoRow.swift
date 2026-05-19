import Foundation

public struct LLMSettingsInfoRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let value: String
    public let detail: String?

    public init(id: String, title: String, value: String, detail: String? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
    }
}
