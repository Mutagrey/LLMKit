struct MLXRuntimeGenerationEvent: Sendable {
    let text: String?
    let generationTimeMilliseconds: Int?
    let tokensPerSecond: Double?

    static func chunk(_ text: String) -> MLXRuntimeGenerationEvent {
        MLXRuntimeGenerationEvent(
            text: text,
            generationTimeMilliseconds: nil,
            tokensPerSecond: nil
        )
    }

    static func info(
        generationTimeMilliseconds: Int?,
        tokensPerSecond: Double?
    ) -> MLXRuntimeGenerationEvent {
        MLXRuntimeGenerationEvent(
            text: nil,
            generationTimeMilliseconds: generationTimeMilliseconds,
            tokensPerSecond: tokensPerSecond
        )
    }
}
