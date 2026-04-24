enum OpenAIStructuredOutputFormatNameMapper {
    static func formatName(_ name: String?) -> String {
        let rawName = (name?.isEmpty == false ? name : "structured_output") ?? "structured_output"
        let filteredScalars = rawName.unicodeScalars.map { scalar -> UnicodeScalar in
            switch scalar.value {
            case 48...57, 65...90, 95, 97...122, 45:
                return scalar
            default:
                return "_"
            }
        }
        let sanitized = String(String.UnicodeScalarView(filteredScalars))
        let trimmed = String(sanitized.prefix(64))
        return trimmed.isEmpty ? "structured_output" : trimmed
    }
}
