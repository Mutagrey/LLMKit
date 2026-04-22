import LLMPrompting
import Testing

@Test func promptAssemblerSubstitutesVariables() {
    let template = PromptTemplate(
        id: "summary",
        version: PromptVersion("1"),
        fragments: [PromptFragment("Hello {{name}}")]
    )
    let snapshot = PromptAssembler().assemble(template, context: PromptContext(variables: ["name": "Ada"]))

    #expect(snapshot.assembledPrompt == "Hello Ada")
}
