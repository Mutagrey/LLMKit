import Foundation

struct MLXStreamOutputSanitizer {
    private static let controlTokens = [
        "<end_of_turn>",
        "<eot_id>"
    ]

    private var rawText = ""
    private var emittedText = ""

    mutating func append(_ delta: String) -> String {
        rawText += delta
        return newlyVisibleText(from: sanitizedStableText(rawText))
    }

    mutating func finish() -> String {
        newlyVisibleText(from: sanitizedStableText(rawText))
    }

    private mutating func newlyVisibleText(from sanitizedText: String) -> String {
        let newText = String(sanitizedText.dropFirst(emittedText.count))
        emittedText = sanitizedText
        return newText
    }

    private func sanitizedStableText(_ text: String) -> String {
        let withoutControlTokens = Self.controlTokens.reduce(text) { partialResult, token in
            partialResult.replacingOccurrences(of: token, with: "")
        }
        let trailingPrefixLength = Self.trailingControlTokenPrefixLength(in: withoutControlTokens)
        guard trailingPrefixLength > 0 else {
            return withoutControlTokens
        }
        return String(withoutControlTokens.dropLast(trailingPrefixLength))
    }

    private static func trailingControlTokenPrefixLength(in text: String) -> Int {
        let maximumLength = min(text.count, controlTokens.map(\.count).max() ?? 0)
        guard maximumLength > 0 else {
            return 0
        }

        for prefixLength in stride(from: maximumLength, through: 1, by: -1) {
            let suffix = String(text.suffix(prefixLength))
            if controlTokens.contains(where: { $0.hasPrefix(suffix) }) {
                return prefixLength
            }
        }

        return 0
    }
}
