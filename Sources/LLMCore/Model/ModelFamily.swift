import Foundation

public enum ModelFamily: Hashable, Codable, Sendable {
    case appleFoundation
    case qwen
    case gemma
    case llama
    case mistral
    case custom(String)
}
