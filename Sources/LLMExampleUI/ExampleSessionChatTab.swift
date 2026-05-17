import LLMCore
import LLMUIChat
import SwiftUI

struct ExampleSessionChatTab: View {
    let viewModel: LLMKitExampleViewModel
    let configuration: LLMKitExampleConfiguration
    let openModels: () -> Void

    @State private var path: [SessionID] = []
    @State private var isPresentingAutomationComposer = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if viewModel.chatSelectableModels.isEmpty {
                    Section {
                        NoReadyModelCard(openModels: openModels)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Manual Chats") {
                    if manualSessions.isEmpty {
                        Text("No chats yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(manualSessions) { overview in
                            NavigationLink(value: overview.id) {
                                ExampleSessionRow(
                                    overview: overview,
                                    descriptor: viewModel.backendDescriptor(for: overview)
                                )
                            }
                        }
                        .onDelete { offsets in
                            deleteSessions(from: manualSessions, at: offsets)
                        }
                    }
                }

                Section("Auto Dialogs") {
                    if automatedSessions.isEmpty {
                        Text("No auto dialogs yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(automatedSessions) { overview in
                            NavigationLink(value: overview.id) {
                                ExampleSessionRow(
                                    overview: overview,
                                    descriptor: viewModel.backendDescriptor(for: overview)
                                )
                            }
                        }
                        .onDelete { offsets in
                            deleteSessions(from: automatedSessions, at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: SessionID.self) { sessionID in
                ExampleSessionDetailHost(
                    sessionID: sessionID,
                    viewModel: viewModel,
                    configuration: configuration
                )
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ChatModelToolbarMenu(
                        models: viewModel.chatSelectableModels,
                        selectedModel: viewModel.selectedModel,
                        selectedStatusText: viewModel.selectedModel.map(viewModel.statusText(for:)) ?? "No model selected",
                        isRefreshing: viewModel.isRefreshing
                    ) { descriptor in
                        viewModel.selectedModelID = descriptor.id
                    } statusText: { descriptor in
                        viewModel.statusText(for: descriptor)
                    }
                }

                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        isPresentingAutomationComposer = true
                    } label: {
                        Image(systemName: "person.3.sequence")
                    }
                    .disabled(viewModel.chatSelectableModels.isEmpty)

                    Button {
                        Task {
                            do {
                                let session = try await viewModel.createManualSession()
                                path.append(session.id)
                            } catch {
                                await MainActor.run {
                                    viewModel.setLastErrorMessage(ChatErrorPresentation(error: error).message)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!viewModel.canChatWithSelectedModel)

                    if viewModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .sheet(isPresented: $isPresentingAutomationComposer) {
                ExampleAutomationComposerSheet(
                    viewModel: viewModel,
                    onCreate: { sessionID in
                        path.append(sessionID)
                    }
                )
            }
        }
    }

    private var manualSessions: [SessionOverview] {
        viewModel.sessions.filter { $0.kind == .manualChat }
    }

    private var automatedSessions: [SessionOverview] {
        viewModel.sessions.filter { $0.kind == .automatedConversation }
    }

    private func deleteSessions(from sessions: [SessionOverview], at offsets: IndexSet) {
        for offset in offsets {
            guard sessions.indices.contains(offset) else {
                continue
            }
            let sessionID = sessions[offset].id
            Task {
                try? await viewModel.deleteSession(id: sessionID)
            }
        }
    }
}

private struct NoReadyModelCard: View {
    let openModels: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "cpu")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 48, height: 48)
                .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("No ready chat model")
                    .font(.headline)
                Text("Install or select a ready model in Models before starting a chat.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button("Models", action: openModels)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ExampleSessionRow: View {
    let overview: SessionOverview
    let descriptor: ModelDescriptor?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(timestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let preview = overview.lastMessagePreview, !preview.isEmpty {
                Text(preview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        if let title = overview.title, !title.isEmpty {
            return title
        }
        return overview.kind == .manualChat ? "New chat" : "Auto dialog"
    }

    private var subtitle: String? {
        switch overview.kind {
        case .manualChat:
            guard let descriptor else {
                return nil
            }
            return "\(descriptor.displayName) · \(exampleBackendTitle(descriptor.backend))"
        case .automatedConversation:
            let phase = overview.automationState?.phase.rawValue.replacingOccurrences(of: "_", with: " ") ?? "idle"
            let modelName = descriptor?.displayName ?? "Multiple models"
            return "\(modelName) · \(phase.capitalized)"
        }
    }

    private var timestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: overview.updatedAt, relativeTo: Date())
    }
}

private struct ExampleSessionDetailHost: View {
    let sessionID: SessionID
    let viewModel: LLMKitExampleViewModel
    let configuration: LLMKitExampleConfiguration

    @State private var snapshot: SessionSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let snapshot {
                switch snapshot.kind {
                case .manualChat:
                    ExampleManualSessionScreen(
                        snapshot: snapshot,
                        descriptor: viewModel.backendDescriptor(for: snapshot.overview),
                        preflight: {
                            try await viewModel.validateExecutionRequirements(
                                snapshot.executionRequirements ?? ExecutionRequirements(requiredCapabilities: [.chat]),
                                context: "Manual chat"
                            )
                        },
                        configuration: configuration,
                        onSessionChanged: {
                            try? await viewModel.refreshSessions()
                        }
                    )
                case .automatedConversation:
                    ExampleAutomatedSessionScreen(
                        snapshot: snapshot,
                        viewModel: viewModel,
                        configuration: configuration,
                        onSessionChanged: {
                            try? await viewModel.refreshSessions()
                        }
                    )
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Session Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
            }
        }
        .task(id: sessionID) {
            do {
                snapshot = try await viewModel.loadSession(id: sessionID)
                errorMessage = snapshot == nil ? "The selected session could not be loaded." : nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ExampleManualSessionScreen: View {
    let preflight: @MainActor @Sendable () async throws -> Void
    let configuration: LLMKitExampleConfiguration
    let onSessionChanged: @Sendable () async -> Void

    @State private var viewModel: ChatViewModel
    private let title: String
    private let descriptor: ModelDescriptor?
    private let sessionID: SessionID

    init(
        snapshot: SessionSnapshot,
        descriptor: ModelDescriptor?,
        preflight: @escaping @MainActor @Sendable () async throws -> Void,
        configuration: LLMKitExampleConfiguration,
        onSessionChanged: @escaping @Sendable () async -> Void
    ) {
        self.preflight = preflight
        self.configuration = configuration
        self.onSessionChanged = onSessionChanged
        self.sessionID = snapshot.id
        self.descriptor = descriptor
        self.title = snapshot.descriptor.title ?? "New chat"
        self._viewModel = State(initialValue: ChatViewModel(
            messages: snapshot.messages,
            chatService: configuration.container.chat,
            requirements: snapshot.executionRequirements ?? ExecutionRequirements(requiredCapabilities: [.chat]),
            sessionID: snapshot.id,
            onMessageAppended: { message in
                Task {
                    if (try? await configuration.container.sessions.append(message, to: snapshot.id)) != nil {
                        await onSessionChanged()
                    }
                }
            },
            beforeSend: {
                try await preflight()
            }
        ))
    }

    var body: some View {
        ChatScreen(
            title: titleLine,
            viewModel: viewModel
        )
    }

    private var titleLine: String {
        if let descriptor {
            return "\(title) · \(descriptor.displayName) · \(exampleBackendTitle(descriptor.backend))"
        }
        return title
    }
}

private struct ExampleAutomatedSessionScreen: View {
    let viewModel: LLMKitExampleViewModel
    let configuration: LLMKitExampleConfiguration
    let onSessionChanged: @Sendable () async -> Void

    @State private var snapshot: SessionSnapshot
    @State private var isRunningAction = false

    init(
        snapshot: SessionSnapshot,
        viewModel: LLMKitExampleViewModel,
        configuration: LLMKitExampleConfiguration,
        onSessionChanged: @escaping @Sendable () async -> Void
    ) {
        self.viewModel = viewModel
        self.configuration = configuration
        self.onSessionChanged = onSessionChanged
        self._snapshot = State(initialValue: snapshot)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let definition = snapshot.automationDefinition {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(definition.topic)
                            .font(.headline)
                        Text(participantLine(for: definition))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(statusLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let summary = snapshot.summary, !summary.text.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.headline)
                            Text(summary.text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(snapshot.messages) { message in
                            Text(message.content.text)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(snapshot.descriptor.title ?? "Auto dialog")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    run(action: .start)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }

                Button {
                    run(action: .step)
                } label: {
                    Label("Step", systemImage: "forward.frame")
                }

                Button {
                    run(action: .pause)
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.background)
        }
        .overlay {
            if isRunningAction {
                ProgressView()
            }
        }
    }

    private var statusLine: String {
        let state = snapshot.automationState ?? AutomatedConversationRunState()
        let errorSuffix = state.lastErrorMessage.map { " · \($0)" } ?? ""
        return "\(state.phase.rawValue.capitalized) · \(state.completedTurns) turns\(errorSuffix)"
    }

    private func participantLine(for definition: AutomatedConversationDefinition) -> String {
        definition.participants.map(\.displayName).joined(separator: " · ")
    }

    private func run(action: AutomationAction) {
        isRunningAction = true
        Task {
            defer {
                Task { @MainActor in
                    isRunningAction = false
                }
            }
            let coordinator = configuration.makeAutomationCoordinator()
            do {
                try await viewModel.validateAutomatedSession(snapshot)
                let updated: SessionSnapshot
                switch action {
                case .start:
                    updated = try await coordinator.runBatch(sessionID: snapshot.id, maxTurns: 3)
                case .step:
                    updated = try await coordinator.runBatch(sessionID: snapshot.id, maxTurns: 1)
                case .pause:
                    updated = try await coordinator.pause(sessionID: snapshot.id)
                }
                await MainActor.run {
                    snapshot = updated
                }
                await onSessionChanged()
            } catch {
                await MainActor.run {
                    snapshot = snapshot.withFailureMessage(ChatErrorPresentation(error: error).message)
                }
            }
        }
    }

    private enum AutomationAction {
        case start
        case step
        case pause
    }
}

private struct ExampleAutomationComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: LLMKitExampleViewModel
    let onCreate: (SessionID) -> Void

    @State private var title = ""
    @State private var topic = ""
    @State private var maxTurns = 8
    @State private var usesSharedModel = true
    @State private var participants: [AutomationParticipantDraft]

    init(viewModel: LLMKitExampleViewModel, onCreate: @escaping (SessionID) -> Void) {
        self.viewModel = viewModel
        self.onCreate = onCreate
        let defaultModelID = viewModel.selectedModel?.id
        self._participants = State(initialValue: [
            AutomationParticipantDraft(
                displayName: "Researcher",
                role: "Explore the topic and add concrete detail.",
                instructions: "",
                modelID: defaultModelID
            ),
            AutomationParticipantDraft(
                displayName: "Reviewer",
                role: "Challenge weak assumptions and tighten the argument.",
                instructions: "",
                modelID: defaultModelID
            )
        ])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Conversation") {
                    TextField("Title", text: $title)
                    TextField("Topic", text: $topic, axis: .vertical)
                    Stepper("Max Turns: \(maxTurns)", value: $maxTurns, in: 2...64, step: 2)
                    Toggle("Shared model", isOn: $usesSharedModel)
                }

                Section("Participants") {
                    ForEach($participants) { draft in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: draft.displayName)
                            TextField("Role", text: draft.role, axis: .vertical)
                            TextField("Instructions", text: draft.instructions, axis: .vertical)

                            if !usesSharedModel {
                                Picker("Model", selection: draft.modelID) {
                                    Text("No model").tag(Optional<ModelID>.none)
                                    ForEach(availableModels, id: \.id) { descriptor in
                                        Text(descriptor.displayName).tag(Optional(descriptor.id))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        participants.remove(atOffsets: offsets)
                    }

                    Button {
                        participants.append(AutomationParticipantDraft(
                            displayName: "Speaker \(participants.count + 1)",
                            role: "Contribute another perspective to the discussion.",
                            instructions: "",
                            modelID: viewModel.selectedModel?.id
                        ))
                    } label: {
                        Label("Add participant", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Auto Dialog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSession()
                    }
                    .disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || participants.isEmpty)
                }
            }
        }
    }

    private var availableModels: [ModelDescriptor] {
        viewModel.chatSelectableModels
    }

    private func createSession() {
        let automationParticipants = participants.map { draft in
            AutomatedConversationParticipant(
                id: draft.id.uuidString,
                displayName: draft.displayName,
                role: draft.role,
                instructions: draft.instructions,
                selectionPolicy: usesSharedModel ? nil : draft.modelID.map { .require($0) }
            )
        }
        let baseRequirements = sharedRequirements()
        let definition = AutomatedConversationDefinition(
            topic: topic.trimmingCharacters(in: .whitespacesAndNewlines),
            participants: automationParticipants,
            sharedExecutionRequirements: baseRequirements,
            maxTurns: maxTurns,
            backgroundPolicy: .bestEffort
        )

        Task {
            do {
                let snapshot = try await viewModel.createAutomatedSession(
                    title: title.isEmpty ? topic : title,
                    definition: definition,
                    executionRequirements: baseRequirements
                )
                await MainActor.run {
                    dismiss()
                    onCreate(snapshot.id)
                }
            } catch {
                await MainActor.run {
                    viewModel.setLastErrorMessage(ChatErrorPresentation(error: error).message)
                }
            }
        }
    }

    private func sharedRequirements() -> ExecutionRequirements {
        if usesSharedModel, let model = viewModel.selectedModel {
            return viewModel.requirements(for: model, preferredLatency: .background)
        }

        let selectedDescriptors = participants.compactMap { participant in
            viewModel.model(for: participant.modelID)
        }
        let contextLimit = selectedDescriptors.compactMap(\.contextWindowTokens).min()
        return ExecutionRequirements(
            requiredCapabilities: [.chat],
            selectionPolicy: .automatic,
            executionMode: viewModel.executionMode,
            preferredLatency: .background,
            qualityTier: viewModel.qualityTier,
            privacyMode: viewModel.privacyMode,
            budget: ExecutionBudget(maxInputTokens: contextLimit, maxOutputTokens: viewModel.maxOutputTokens)
        )
    }
}

private struct AutomationParticipantDraft: Identifiable, Hashable {
    let id = UUID()
    var displayName: String
    var role: String
    var instructions: String
    var modelID: ModelID?
}

private extension SessionSnapshot {
    func withFailureMessage(_ message: String) -> SessionSnapshot {
        SessionSnapshot(
            id: id,
            descriptor: descriptor,
            kind: kind,
            messages: messages,
            summary: summary,
            executionRequirements: executionRequirements,
            automationDefinition: automationDefinition,
            automationState: AutomatedConversationRunState(
                phase: .failed,
                completedTurns: automationState?.completedTurns ?? 0,
                nextParticipantIndex: automationState?.nextParticipantIndex ?? 0,
                lastErrorMessage: message,
                lastUpdatedAt: Date()
            )
        )
    }
}
