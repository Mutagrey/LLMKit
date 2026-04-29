import BackgroundTasks
import Foundation
import LLMCore
import LLMExampleUI

@MainActor
final class DemoAutomationBackgroundController {
    static let taskIdentifier = "com.llmkit.demo.automation"

    private let configurationProvider: @Sendable () -> LLMKitExampleConfiguration

    init(configurationProvider: @escaping @Sendable () -> LLMKitExampleConfiguration) {
        self.configurationProvider = configurationProvider
    }

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(processingTask)
        }
    }

    func resumeForegroundSessionsIfNeeded() {
        let configuration = configurationProvider()
        Task { [configuration] in
            let coordinator = configuration.makeAutomationCoordinator()
            _ = try? await coordinator.resumeRunningSessions(maxTurnsPerSession: 1)
        }
    }

    func scheduleIfNeeded() {
        Task { [configurationProvider] in
            guard await Self.hasBestEffortSessionsNeedingWork(configurationProvider: configurationProvider) else {
                return
            }

            let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 30)
            request.requiresNetworkConnectivity = false
            request.requiresExternalPower = false
            try? BGTaskScheduler.shared.submit(request)
        }
    }

    private func handle(_ task: BGProcessingTask) {
        scheduleIfNeeded()

        let configurationProvider = self.configurationProvider

        let runner = Task { [configurationProvider] in
            let configuration = configurationProvider()
            let coordinator = configuration.makeAutomationCoordinator()
            _ = try? await coordinator.resumeRunningSessions(maxTurnsPerSession: 3)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { [configurationProvider] in
            runner.cancel()
            Task {
                let configuration = configurationProvider()
                let coordinator = configuration.makeAutomationCoordinator()
                for overview in (try? await configuration.container.sessions.listSessions()) ?? [] where overview.kind == .automatedConversation && overview.automationState?.phase == .running {
                    _ = try? await coordinator.pause(sessionID: overview.id)
                }
                task.setTaskCompleted(success: false)
            }
        }
    }

    private static func hasBestEffortSessionsNeedingWork(configurationProvider: @escaping @Sendable () -> LLMKitExampleConfiguration) async -> Bool {
        let configuration = configurationProvider()
        let overviews = (try? await configuration.container.sessions.listSessions()) ?? []
        for overview in overviews where overview.kind == .automatedConversation && overview.automationState?.phase == .running {
            guard let snapshot = try? await configuration.container.sessions.loadSession(id: overview.id),
                  snapshot.automationDefinition?.backgroundPolicy == .bestEffort else {
                continue
            }
            return true
        }
        return false
    }
}
