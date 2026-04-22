import Foundation

public struct SSEEvent: Hashable, Sendable {
    public let event: String?
    public let data: String

    public init(event: String? = nil, data: String) {
        self.event = event
        self.data = data
    }
}

public struct SSEParser: Sendable {
    public init() {}

    public func parse(_ chunk: String) -> [SSEEvent] {
        chunk
            .components(separatedBy: "\n\n")
            .compactMap { block in
                let lines = block.split(separator: "\n", omittingEmptySubsequences: true)
                guard !lines.isEmpty else { return nil }
                var eventName: String?
                var dataLines: [String] = []
                for line in lines {
                    if line.hasPrefix("event:") {
                        eventName = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        dataLines.append(String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces))
                    }
                }
                guard !dataLines.isEmpty else { return nil }
                return SSEEvent(event: eventName, data: dataLines.joined(separator: "\n"))
            }
    }
}
