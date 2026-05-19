import LLMCore
import LLMUIChat
import LLMUIModels
import SwiftUI

struct ChatSessionsTab: View {
    let viewModel: DemoViewModel
    let configuration: DemoRuntimeConfiguration
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

                sessionsSection("Manual Chats", sessions: manualSessions)
                sessionsSection("Auto Dialogs", sessions: automatedSessions)
            }
            .navigationTitle("Chats")
            .navigationDestination(for: SessionID.self) { sessionID in
                SessionDetailHost(
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

                    Button(action: createManualSession) {
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
                AutomationComposerSheet(
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

    private func sessionsSection(_ title: String, sessions: [SessionOverview]) -> some View {
        Section(title) {
            if sessions.isEmpty {
                Text(title == "Manual Chats" ? "No chats yet" : "No auto dialogs yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { overview in
                    NavigationLink(value: overview.id) {
                        SessionRow(
                            overview: overview,
                            descriptor: viewModel.backendDescriptor(for: overview)
                        )
                    }
                }
                .onDelete { offsets in
                    deleteSessions(from: sessions, at: offsets)
                }
            }
        }
    }

    private func createManualSession() {
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
    }

    private func deleteSessions(from sessions: [SessionOverview], at offsets: IndexSet) {
        for sessionID in offsets.compactMap({ sessions.indices.contains($0) ? sessions[$0].id : nil }) {
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

private struct SessionRow: View {
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
            return "\(descriptor.displayName) · \(ModelFormatting.backendTitle(descriptor.backend))"
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
