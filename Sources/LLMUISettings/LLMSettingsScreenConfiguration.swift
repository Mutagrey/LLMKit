import Foundation
import LLMSettings

public struct LLMSettingsScreenConfiguration: Hashable, Sendable {
    public var visibleSections: Set<LLMSettingsSection>
    public var constraints: LLMSettingsConstraints
    public var allowsRoutingControls: Bool
    public var showsRemoteRoutingModes: Bool
    public var showsAdvancedRuntimeControls: Bool
    public var title: String

    public init(
        visibleSections: Set<LLMSettingsSection> = Set(LLMSettingsSection.allCases),
        constraints: LLMSettingsConstraints = .recommended,
        allowsRoutingControls: Bool = true,
        showsRemoteRoutingModes: Bool = true,
        showsAdvancedRuntimeControls: Bool = true,
        title: String = "AI Settings"
    ) {
        self.visibleSections = visibleSections
        self.constraints = constraints
        self.allowsRoutingControls = allowsRoutingControls
        self.showsRemoteRoutingModes = showsRemoteRoutingModes
        self.showsAdvancedRuntimeControls = showsAdvancedRuntimeControls
        self.title = title
    }
}
