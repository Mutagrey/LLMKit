import Foundation

public struct StreamedTextAccumulator: Hashable, Codable, Sendable {
    public private(set) var text: String

    public init(text: String = "") {
        self.text = text
    }

    @discardableResult
    public mutating func append(_ delta: String) -> String {
        text += delta
        return text
    }

    public var isEmpty: Bool {
        text.isEmpty
    }
}
