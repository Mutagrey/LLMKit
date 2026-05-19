import Foundation
import LLMCore
import SwiftUI

public struct ModelCatalogCardView: View {
    private let descriptor: ModelDescriptor
    private let status: String
    private let isAvailable: Bool
    private let isSelected: Bool
    private let installState: InstallState?
    private let progressDetail: ModelInstallProgress?
    private let installedSizeBytes: Int64?
    private let isInstallButtonDisabled: Bool
    private let selectionAction: (() -> Void)?
    private let installAction: (() async -> Void)?
    private let cancelAction: (() async -> Void)?
    private let deleteAction: (() async -> Void)?
    private let detailsAction: (() -> Void)?

    public init(
        descriptor: ModelDescriptor,
        status: String,
        isAvailable: Bool,
        isSelected: Bool = false,
        installState: InstallState? = nil,
        progressDetail: ModelInstallProgress? = nil,
        installedSizeBytes: Int64? = nil,
        isInstallButtonDisabled: Bool = false,
        selectionAction: (() -> Void)? = nil,
        installAction: (() async -> Void)? = nil,
        cancelAction: (() async -> Void)? = nil,
        deleteAction: (() async -> Void)? = nil,
        detailsAction: (() -> Void)? = nil
    ) {
        self.descriptor = descriptor
        self.status = status
        self.isAvailable = isAvailable
        self.isSelected = isSelected
        self.installState = installState
        self.progressDetail = progressDetail
        self.installedSizeBytes = installedSizeBytes
        self.isInstallButtonDisabled = isInstallButtonDisabled
        self.selectionAction = selectionAction
        self.installAction = installAction
        self.cancelAction = cancelAction
        self.deleteAction = deleteAction
        self.detailsAction = detailsAction
    }

    public var body: some View {
        ModelDownloadRowContent(
            descriptor: descriptor,
            status: status,
            isAvailable: isAvailable,
            isSelected: isSelected,
            installState: installState,
            progressDetail: progressDetail,
            installedSizeBytes: installedSizeBytes,
            isInstallButtonDisabled: isInstallButtonDisabled,
            selectionAction: selectionAction,
            installAction: installAction,
            cancelAction: cancelAction
        )
        .swipeActions(edge: .trailing) {
            if let deleteAction {
                Button(role: .destructive) {
                    Task { await deleteAction() }
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .accessibilityLabel("Delete model")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                detailsAction?()
            } label: {
                Image(systemName: "info.circle")
            }
            .tint(.blue)
            .accessibilityLabel("Model details")
        }
    }
}

#Preview {
    ModelCatalogCardView(
        descriptor: .init(
            id: "test",
            displayName: "Test Model",
            family: .custom("Custom Family"),
            backend: .coreML,
            capabilities: [.offline, .chat],
            minimumRAMGB: 8,
            tags: ["downloadable"]
        ),
        status: "Not installed",
        isAvailable: false,
        installState: .notInstalled,
        installAction: {},
        detailsAction: {}
    )
}
