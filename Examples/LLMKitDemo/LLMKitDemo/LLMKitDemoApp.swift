import BackgroundTasks
import SwiftUI

@main
struct LLMKitDemoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let configuration = DemoConfiguration.make()
    private let backgroundController = DemoAutomationBackgroundController(configurationProvider: DemoConfiguration.make)

    init() {
        backgroundController.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(configuration: configuration)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                backgroundController.resumeForegroundSessionsIfNeeded()
            case .background:
                backgroundController.scheduleIfNeeded()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
