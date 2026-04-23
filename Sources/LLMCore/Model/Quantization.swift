import Foundation

public struct Quantization: Hashable, Codable, Sendable {
    public let format: String
    public let bits: Int?

    public init(format: String, bits: Int? = nil) {
        self.format = format
        self.bits = bits
    }
}
