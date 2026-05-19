import Foundation
import LLMSettings

public struct LLMSettingsActions {
    public var onSettingsChanged: (@MainActor (LLMRuntimeSettings) -> Void)?
    public var openModelSettings: (@MainActor () -> Void)?
    public var openSessionSettings: (@MainActor () -> Void)?
    public var resetPrompt: (@MainActor () -> Void)?

    public init(
        onSettingsChanged: (@MainActor (LLMRuntimeSettings) -> Void)? = nil,
        openModelSettings: (@MainActor () -> Void)? = nil,
        openSessionSettings: (@MainActor () -> Void)? = nil,
        resetPrompt: (@MainActor () -> Void)? = nil
    ) {
        self.onSettingsChanged = onSettingsChanged
        self.openModelSettings = openModelSettings
        self.openSessionSettings = openSessionSettings
        self.resetPrompt = resetPrompt
    }
}
