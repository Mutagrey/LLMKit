import LLMCore

enum OpenAIResponsesStructuredOutputMapper {
    static func textConfiguration(for schema: StructuredOutputSchema?) -> OpenAIResponsesTextConfiguration? {
        guard let schema else {
            return nil
        }

        return OpenAIResponsesTextConfiguration(
            format: OpenAIResponsesTextFormat(
                type: "json_schema",
                name: OpenAIStructuredOutputFormatNameMapper.formatName(schema.name),
                schema: schema.definition,
                strict: true
            )
        )
    }
}
