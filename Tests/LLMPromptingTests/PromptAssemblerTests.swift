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

@Test func promptAssemblerJoinsFragmentsWithNewlines() {
    let template = PromptTemplate(
        id: "joined",
        version: PromptVersion("1"),
        fragments: [
            PromptFragment("First"),
            PromptFragment("Second")
        ]
    )

    let snapshot = PromptAssembler().assemble(template)

    #expect(snapshot.assembledPrompt == "First\nSecond")
}

@Test func promptAssemblerPreservesUnknownPlaceholders() {
    let template = PromptTemplate(
        id: "unknown",
        version: PromptVersion("1"),
        fragments: [PromptFragment("Hello {{known}} {{missing}}")]
    )

    let snapshot = PromptAssembler().assemble(template, context: PromptContext(variables: ["known": "Ada"]))

    #expect(snapshot.assembledPrompt == "Hello Ada {{missing}}")
}

@Test func promptAssemblerSubstitutesRepeatedVariables() {
    let template = PromptTemplate(
        id: "repeated",
        version: PromptVersion("1"),
        fragments: [PromptFragment("{{name}} met {{name}}")]
    )

    let snapshot = PromptAssembler().assemble(template, context: PromptContext(variables: ["name": "Ada"]))

    #expect(snapshot.assembledPrompt == "Ada met Ada")
}

@Test func promptAssemblerAllowsEmptyTemplate() {
    let template = PromptTemplate(
        id: "empty",
        version: PromptVersion("1"),
        fragments: []
    )

    let snapshot = PromptAssembler().assemble(template)

    #expect(snapshot.templateID == "empty")
    #expect(snapshot.assembledPrompt.isEmpty)
}

@Test func promptRegistryReplacesTemplateWithSameID() async {
    let first = PromptTemplate(
        id: "summary",
        version: PromptVersion("1"),
        fragments: [PromptFragment("First")]
    )
    let second = PromptTemplate(
        id: "summary",
        version: PromptVersion("2"),
        fragments: [PromptFragment("Second")]
    )
    let registry = PromptRegistry(templates: [first])

    await registry.register(second)

    #expect(await registry.template(id: "summary") == second)
}

@Test func promptRegistryReturnsNilForUnknownTemplate() async {
    let registry = PromptRegistry()

    #expect(await registry.template(id: "missing") == nil)
}
