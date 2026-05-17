import Foundation

public enum ModelFamily: Hashable, Codable, Sendable {
    case appleFoundation
    case qwen
    case gemma
    case llama
    case mistral
    case custom(String)
    
    public var title: String {
        switch self {
        case .appleFoundation: return "Apple Foundation"
        case .qwen: return "Qwen"
        case .gemma: return "Gemma"
        case .llama: return "Llama"
        case .mistral: return "Mistral"
        case .custom(let title): return title.capitalized
        }
    }
    
    var baseModels: [ModelFamily] {
        [.appleFoundation, .qwen, .gemma, .llama, .mistral]
    }
}
