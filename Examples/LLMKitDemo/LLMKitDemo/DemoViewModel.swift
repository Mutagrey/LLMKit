import LLMCore
import LLMModelLifecycle
import LLMOrchestrator
import LLMProtocols
import Observation

@MainActor
@Observable
final class DemoViewModel {
    var messages: [ChatMessage] = []
    var installState: InstallState = .notInstalled
    var isSending = false
    var errorMessage: String?

    private let model: ModelDescriptor
    private let chatService: DefaultChatService
    private let lifecycleService: ModelInstallCoordinator

    init() {
        let model = ModelDescriptor(
            id: "demo.echo",
            displayName: "Demo Echo",
            family: .custom("demo"),
            backend: .custom("demo"),
            capabilities: [.chat, .completion, .streaming],
            supportsStreaming: true
        )
        self.model = model
        self.lifecycleService = ModelInstallCoordinator()

        let catalog = DefaultModelCatalog(models: [model])
        let registry = BackendRegistry(backends: [DemoEchoBackend()])
        self.chatService = DefaultChatService(router: ModelRouter(catalog: catalog), registry: registry)
    }

    func installDemoModel() async {
        do {
            for try await event in lifecycleService.install(model) {
                switch event {
                case .stateChanged(_, let state):
                    installState = state
                case .progress(_, let progress):
                    installState = .downloading(progress: progress)
                case .completed(let record):
                    installState = record.installState
                case .failed(_, let error):
                    errorMessage = String(describing: error)
                }
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: MessageContent(text: trimmed))
        messages.append(userMessage)
        isSending = true
        errorMessage = nil

        var accumulator = StreamedTextAccumulator()
        let request = ChatRequest(messages: messages, requirements: ExecutionRequirements(requiredCapabilities: [.chat]))
        do {
            for try await event in chatService.send(request) {
                switch event {
                case .delta(let text):
                    accumulator.append(text)
                case .completed(let result):
                    messages.append(result.message)
                case .failed(let error):
                    throw error
                case .started, .toolCallRequested, .toolCallCompleted:
                    break
                }
            }
            if !accumulator.isEmpty, messages.last?.role != .assistant {
                messages.append(ChatMessage(role: .assistant, content: MessageContent(text: accumulator.text)))
            }
        } catch {
            errorMessage = String(describing: error)
        }

        isSending = false
    }
}
