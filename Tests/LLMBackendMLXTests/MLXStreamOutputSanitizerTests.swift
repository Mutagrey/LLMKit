@testable import LLMBackendMLX
import Testing

@Test func mlxStreamOutputSanitizerRemovesWholeControlTokens() {
    var sanitizer = MLXStreamOutputSanitizer()

    let outcome = sanitizer.append("hello<end_of_turn>world")

    #expect(outcome.visibleText == "hello")
    #expect(outcome.shouldStop)
    #expect(sanitizer.finish().isEmpty)
}

@Test func mlxStreamOutputSanitizerRemovesSplitControlTokensAcrossChunks() {
    var sanitizer = MLXStreamOutputSanitizer()

    let first = sanitizer.append("hello<end_")
    let second = sanitizer.append("of_turn>world")

    #expect(first.visibleText == "hello")
    #expect(!first.shouldStop)
    #expect(second.visibleText.isEmpty)
    #expect(second.shouldStop)
    #expect(sanitizer.finish().isEmpty)
}

@Test func mlxStreamOutputSanitizerRemovesTrailingPartialControlToken() {
    var sanitizer = MLXStreamOutputSanitizer()

    let outcome = sanitizer.append("hello<eot")

    #expect(outcome.visibleText == "hello")
    #expect(!outcome.shouldStop)
    #expect(sanitizer.finish().isEmpty)
}
