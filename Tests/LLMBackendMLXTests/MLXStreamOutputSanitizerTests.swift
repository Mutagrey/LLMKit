@testable import LLMBackendMLX
import Testing

@Test func mlxStreamOutputSanitizerRemovesWholeControlTokens() {
    var sanitizer = MLXStreamOutputSanitizer()

    let visible = sanitizer.append("hello<end_of_turn>world")

    #expect(visible == "helloworld")
    #expect(sanitizer.finish().isEmpty)
}

@Test func mlxStreamOutputSanitizerRemovesSplitControlTokensAcrossChunks() {
    var sanitizer = MLXStreamOutputSanitizer()

    let first = sanitizer.append("hello<end_")
    let second = sanitizer.append("of_turn>world")

    #expect(first == "hello")
    #expect(second == "world")
    #expect(sanitizer.finish().isEmpty)
}

@Test func mlxStreamOutputSanitizerRemovesTrailingPartialControlToken() {
    var sanitizer = MLXStreamOutputSanitizer()

    let visible = sanitizer.append("hello<eot")

    #expect(visible == "hello")
    #expect(sanitizer.finish().isEmpty)
}
