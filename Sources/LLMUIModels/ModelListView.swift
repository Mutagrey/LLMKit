import Foundation
import LLMCore
import SwiftUI

public struct ModelListView: View {
    private let models: [ModelDescriptor]
    private let selectedModelID: ModelID?
    private let isRefreshing: Bool
    private let errorMessage: String?
    private let storageSummary: ModelStorageSummary?
    private let statusText: (ModelDescriptor) -> String
    private let isReadyForChat: (ModelDescriptor) -> Bool
    private let installState: (ModelDescriptor) -> InstallState?
    private let progressDetail: (ModelDescriptor) -> ModelInstallProgress?
    private let installedSizeBytes: (ModelDescriptor) -> Int64?
    private let isInstallButtonDisabled: (ModelDescriptor) -> Bool
    private let canDeleteArtifacts: (ModelDescriptor) -> Bool
    private let selectAction: (ModelDescriptor) -> Void
    private let installAction: (ModelDescriptor) async -> Void
    private let cancelAction: (ModelDescriptor) async -> Void
    private let deleteAction: (ModelDescriptor) async -> Void
    private let refreshAction: () async -> Void

    @State private var presentedModel: PresentedModel?
    @State private var searchText = ""
    @State private var backendFilter: ModelBackendFilter = .all
    @State private var installFilter: ModelInstallFilter = .all
    @State private var sortOrder: ModelSortOrder = .recommended
    @State private var grouping: ModelGrouping = .backend

    public init(
        models: [ModelDescriptor],
        selectedModelID: ModelID?,
        isRefreshing: Bool = false,
        errorMessage: String? = nil,
        storageSummary: ModelStorageSummary? = nil,
        statusText: @escaping (ModelDescriptor) -> String,
        isReadyForChat: @escaping (ModelDescriptor) -> Bool,
        installState: @escaping (ModelDescriptor) -> InstallState?,
        progressDetail: @escaping (ModelDescriptor) -> ModelInstallProgress?,
        installedSizeBytes: @escaping (ModelDescriptor) -> Int64?,
        isInstallButtonDisabled: @escaping (ModelDescriptor) -> Bool,
        canDeleteArtifacts: @escaping (ModelDescriptor) -> Bool,
        selectAction: @escaping (ModelDescriptor) -> Void,
        installAction: @escaping (ModelDescriptor) async -> Void,
        cancelAction: @escaping (ModelDescriptor) async -> Void,
        deleteAction: @escaping (ModelDescriptor) async -> Void,
        refreshAction: @escaping () async -> Void
    ) {
        self.models = models
        self.selectedModelID = selectedModelID
        self.isRefreshing = isRefreshing
        self.errorMessage = errorMessage
        self.storageSummary = storageSummary
        self.statusText = statusText
        self.isReadyForChat = isReadyForChat
        self.installState = installState
        self.progressDetail = progressDetail
        self.installedSizeBytes = installedSizeBytes
        self.isInstallButtonDisabled = isInstallButtonDisabled
        self.canDeleteArtifacts = canDeleteArtifacts
        self.selectAction = selectAction
        self.installAction = installAction
        self.cancelAction = cancelAction
        self.deleteAction = deleteAction
        self.refreshAction = refreshAction
    }

    public var body: some View {
        List {
            if let storageSummary {
                StorageUsageView(summary: storageSummary)
                    .listRowSeparator(.hidden)
            }

            ForEach(modelSections) { section in
                Section(section.title) {
                    ForEach(section.models, id: \.self) { descriptor in
                        modelCard(for: descriptor)
                    }
                }
            }
        }
        .navigationTitle("Models")
        .searchable(text: $searchText, prompt: "Search models")
        .toolbar {
            filterMenu
            displayMenu
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
            }
        }
        .refreshable {
            await refreshAction()
        }
        .sheet(item: $presentedModel) { item in
            NavigationStack {
                ModelDetailView(
                    descriptor: item.descriptor,
                    status: statusText(item.descriptor),
                    isAvailable: isReadyForChat(item.descriptor)
                )
                .navigationTitle(item.descriptor.displayName)
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Backend", selection: $backendFilter) {
                ForEach(ModelBackendFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            Picker("State", selection: $installFilter) {
                ForEach(ModelInstallFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var displayMenu: some View {
        Menu {
            Picker("Sort", selection: $sortOrder) {
                ForEach(ModelSortOrder.allCases, id: \.self) { order in
                    Text(order.title).tag(order)
                }
            }
            Picker("Group", selection: $grouping) {
                ForEach(ModelGrouping.allCases, id: \.self) { group in
                    Text(group.title).tag(group)
                }
            }
        } label: {
            Label("View", systemImage: "square.grid.2x2")
        }
    }

    private var filteredModels: [ModelDescriptor] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return models.filter { descriptor in
            backendFilter.matches(descriptor) &&
                installFilter.matches(descriptor, context: context) &&
                matchesSearch(descriptor, query: query)
        }
    }

    private var catalogModels: [ModelDescriptor] {
        sortOrder.sorted(filteredModels, context: context)
    }

    private var modelSections: [ModelSection] {
        grouping.sections(for: catalogModels, context: context)
    }

    private var context: ModelListContext {
        ModelListContext(
            statusText: statusText,
            isReadyForChat: isReadyForChat,
            installState: installState
        )
    }

    private func modelCard(for descriptor: ModelDescriptor) -> some View {
        let state = installState(descriptor)
        return ModelRowView(
            descriptor: descriptor,
            status: statusText(descriptor),
            isAvailable: isReadyForChat(descriptor),
            isSelected: descriptor.id == selectedModelID,
            installState: state,
            progressDetail: progressDetail(descriptor),
            installedSizeBytes: installedSizeBytes(descriptor),
            isInstallButtonDisabled: isInstallButtonDisabled(descriptor),
            selectionAction: isReadyForChat(descriptor) ? {
                selectAction(descriptor)
            } : nil,
            installAction: state == nil ? nil : {
                await installAction(descriptor)
            },
            cancelAction: state?.llmUIModelsIsInstalling == true ? {
                await cancelAction(descriptor)
            } : nil,
            deleteAction: canDeleteArtifacts(descriptor) ? {
                await deleteAction(descriptor)
            } : nil,
            detailsAction: {
                presentedModel = PresentedModel(descriptor: descriptor)
            }
        )
    }

    private func matchesSearch(_ descriptor: ModelDescriptor, query: String) -> Bool {
        guard !query.isEmpty else {
            return true
        }
        let searchableText = [
            descriptor.displayName,
            descriptor.id.rawValue,
            descriptor.family.title,
            ModelFormatting.backendTitle(descriptor.backend),
            descriptor.quantization?.format,
            descriptor.source?.repository,
            descriptor.tags.joined(separator: " ")
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        return searchableText.contains(query)
    }
}

private struct PresentedModel: Identifiable {
    let descriptor: ModelDescriptor

    var id: ModelID {
        descriptor.id
    }
}
