public struct PromptAssembler: Sendable {
    public init() {}

    public func assemble(_ template: PromptTemplate, context: PromptContext = PromptContext()) -> PromptDebugSnapshot {
        var prompt = template.fragments.map(\.text).joined(separator: "\n")
        for (key, value) in context.variables {
            prompt = prompt.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return PromptDebugSnapshot(templateID: template.id, assembledPrompt: prompt)
    }
}

public actor PromptRegistry {
    private var templates: [PromptTemplateID: PromptTemplate]

    public init(templates: [PromptTemplate] = []) {
        self.templates = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
    }

    public func register(_ template: PromptTemplate) {
        templates[template.id] = template
    }

    public func template(id: PromptTemplateID) -> PromptTemplate? {
        templates[id]
    }
}
