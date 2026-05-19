import Foundation
import LLMSettings

public struct LLMSettingsActions {
    public var onSettingsChanged: (@MainActor (LLMRuntimeSettings) -> Void)?
    public var openModelSettings: (@MainActor () -> Void)?
    public var openSessionSettings: (@MainActor () -> Void)?
    public var resetPrompt: (@MainActor () -> Void)?
    public var clearModelArtifacts: (@MainActor () async -> Void)?
    public var clearChatSessions: (@MainActor () async -> Void)?
    public var clearInstalledModels: (@MainActor () async -> Void)?

    public init(
        onSettingsChanged: (@MainActor (LLMRuntimeSettings) -> Void)? = nil,
        openModelSettings: (@MainActor () -> Void)? = nil,
        openSessionSettings: (@MainActor () -> Void)? = nil,
        resetPrompt: (@MainActor () -> Void)? = nil,
        clearModelArtifacts: (@MainActor () async -> Void)? = nil,
        clearChatSessions: (@MainActor () async -> Void)? = nil,
        clearInstalledModels: (@MainActor () async -> Void)? = nil
    ) {
        self.onSettingsChanged = onSettingsChanged
        self.openModelSettings = openModelSettings
        self.openSessionSettings = openSessionSettings
        self.resetPrompt = resetPrompt
        self.clearModelArtifacts = clearModelArtifacts
        self.clearChatSessions = clearChatSessions
        self.clearInstalledModels = clearInstalledModels
    }
}
