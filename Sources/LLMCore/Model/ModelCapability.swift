import Foundation

public enum ModelCapability: Hashable, Codable, Sendable {
    case chat
    case completion
    case streaming
    case structuredOutput
    case toolCalling
    case embeddings
    case summarization
    case extraction
    case classification
    case offline
    case multimodalInput
    case lowLatency
    case longContext
    case backgroundExecution
}
