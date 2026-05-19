import Foundation

public struct LLMIntegerSettingBounds: Hashable, Codable, Sendable {
    public let minimum: Int
    public let maximum: Int
    public let step: Int

    public init(minimum: Int, maximum: Int, step: Int) {
        self.minimum = minimum
        self.maximum = max(minimum, maximum)
        self.step = max(1, step)
    }

    public func clamped(_ value: Int) -> Int {
        min(max(value, minimum), maximum)
    }

    public func roundedToStep(_ value: Int) -> Int {
        let clampedValue = clamped(value)
        guard step > 1 else {
            return clampedValue
        }
        let offset = clampedValue - minimum
        let roundedOffset = Int((Double(offset) / Double(step)).rounded()) * step
        return clamped(minimum + roundedOffset)
    }
}
