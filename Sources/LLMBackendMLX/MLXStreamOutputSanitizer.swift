import Foundation

struct MLXStreamOutputSanitizer {
    struct Outcome: Equatable {
        let visibleText: String
        let shouldStop: Bool
    }

    private static let controlTokens = [
        "<end_of_turn>",
        "<eot_id>"
    ]

    private var rawText = ""
    private var emittedText = ""
    private var stopDetected = false

    mutating func append(_ delta: String) -> Outcome {
        guard !stopDetected else {
            return Outcome(visibleText: "", shouldStop: true)
        }

        rawText += delta
        return outcome(from: sanitizedStableText(rawText, isFinal: false))
    }

    mutating func finish() -> String {
        outcome(from: sanitizedStableText(rawText, isFinal: true)).visibleText
    }

    private mutating func outcome(from state: SanitizedState) -> Outcome {
        if state.shouldStop {
            stopDetected = true
        }

        let newText = String(state.visibleText.dropFirst(emittedText.count))
        emittedText = state.visibleText
        return Outcome(visibleText: newText, shouldStop: state.shouldStop)
    }

    private func sanitizedStableText(_ text: String, isFinal: Bool) -> SanitizedState {
        if let stopIndex = Self.firstControlTokenIndex(in: text) {
            return SanitizedState(visibleText: String(text[..<stopIndex]), shouldStop: true)
        }

        let trailingPrefixLength = Self.trailingControlTokenPrefixLength(in: text)
        guard trailingPrefixLength > 0 else {
            return SanitizedState(visibleText: text, shouldStop: false)
        }

        guard isFinal else {
            return SanitizedState(
                visibleText: String(text.dropLast(trailingPrefixLength)),
                shouldStop: false
            )
        }

        return SanitizedState(visibleText: String(text.dropLast(trailingPrefixLength)), shouldStop: false)
    }

    private static func firstControlTokenIndex(in text: String) -> String.Index? {
        controlTokens
            .compactMap { token in
                text.range(of: token)?.lowerBound
            }
            .min()
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

private struct SanitizedState {
    let visibleText: String
    let shouldStop: Bool
}
