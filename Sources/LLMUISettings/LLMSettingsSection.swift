import Foundation

public enum LLMSettingsSection: String, CaseIterable, Hashable, Sendable {
    case overview
    case modelAndRouting
    case contextAndOutput
    case prompt
    case localMemory
    case mlx
    case gguf
    case safety
    case storage
    case reset
}
