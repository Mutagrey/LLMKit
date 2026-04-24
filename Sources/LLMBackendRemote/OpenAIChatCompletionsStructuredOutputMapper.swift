import LLMCore

enum OpenAIChatCompletionsStructuredOutputMapper {
    static func responseFormat(for schema: StructuredOutputSchema?) -> OpenAIChatCompletionResponseFormat? {
        guard let schema else {
            return nil
        }

        return OpenAIChatCompletionResponseFormat(
            type: "json_schema",
            jsonSchema: OpenAIChatCompletionJSONSchemaFormat(
                name: OpenAIStructuredOutputFormatNameMapper.formatName(schema.name),
                schema: schema.definition,
                strict: true
            )
        )
    }
}
