import LLMCore

struct ModelSection: Identifiable {
    let title: String
    let models: [ModelDescriptor]

    var id: String {
        title
    }
}

struct ModelListContext {
    let statusText: (ModelDescriptor) -> String
    let isReadyForChat: (ModelDescriptor) -> Bool
    let installState: (ModelDescriptor) -> InstallState?
}

enum ModelBackendFilter: CaseIterable, Hashable {
    case all
    case apple
    case mlx
    case gguf
    case remote

    var title: String {
        switch self {
        case .all:
            return "All Backends"
        case .apple:
            return "Apple"
        case .mlx:
            return "MLX"
        case .gguf:
            return "GGUF"
        case .remote:
            return "Remote"
        }
    }

    func matches(_ descriptor: ModelDescriptor) -> Bool {
        switch self {
        case .all:
            return true
        case .apple:
            return descriptor.backend == .foundationModels
        case .mlx:
            return descriptor.backend == .mlx
        case .gguf:
            return descriptor.backend == .llamaCpp
        case .remote:
            return descriptor.backend == .remote
        }
    }
}

enum ModelInstallFilter: CaseIterable, Hashable {
    case all
    case ready
    case downloadable
    case installed

    var title: String {
        switch self {
        case .all:
            return "All States"
        case .ready:
            return "Ready"
        case .downloadable:
            return "Downloadable"
        case .installed:
            return "Installed"
        }
    }

    func matches(_ descriptor: ModelDescriptor, context: ModelListContext) -> Bool {
        switch self {
        case .all:
            return true
        case .ready:
            return context.isReadyForChat(descriptor)
        case .downloadable:
            return context.installState(descriptor) != nil
        case .installed:
            return context.installState(descriptor)?.llmUIModelsIsInstalled ?? context.isReadyForChat(descriptor)
        }
    }
}

enum ModelSortOrder: CaseIterable, Hashable {
    case recommended
    case name
    case size
    case memory

    var title: String {
        switch self {
        case .recommended:
            return "Recommended"
        case .name:
            return "Name"
        case .size:
            return "Download Size"
        case .memory:
            return "Memory"
        }
    }

    func sorted(_ models: [ModelDescriptor], context: ModelListContext) -> [ModelDescriptor] {
        models.sorted { lhs, rhs in
            switch self {
            case .recommended:
                return recommendedKey(lhs, context: context) < recommendedKey(rhs, context: context)
            case .name:
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            case .size:
                return sizeKey(lhs) < sizeKey(rhs)
            case .memory:
                return memoryKey(lhs) < memoryKey(rhs)
            }
        }
    }

    private func recommendedKey(_ descriptor: ModelDescriptor, context: ModelListContext) -> ModelSortKey {
        ModelSortKey(
            readyRank: context.isReadyForChat(descriptor) ? 0 : 1,
            backendRank: backendRank(descriptor.backend),
            tagRank: tagRank(descriptor.tags),
            size: descriptor.estimatedDownloadSizeBytes ?? .max,
            name: descriptor.displayName
        )
    }

    private func sizeKey(_ descriptor: ModelDescriptor) -> ModelSortKey {
        ModelSortKey(readyRank: 0, backendRank: 0, tagRank: 0, size: descriptor.estimatedDownloadSizeBytes ?? .max, name: descriptor.displayName)
    }

    private func memoryKey(_ descriptor: ModelDescriptor) -> ModelSortKey {
        ModelSortKey(readyRank: 0, backendRank: descriptor.minimumRAMGB ?? .max, tagRank: 0, size: descriptor.estimatedDownloadSizeBytes ?? .max, name: descriptor.displayName)
    }

    private func backendRank(_ backend: BackendKind) -> Int {
        switch backend {
        case .foundationModels:
            return 0
        case .mlx:
            return 1
        case .llamaCpp:
            return 2
        case .remote:
            return 3
        case .coreML:
            return 4
        case .executorch:
            return 5
        case .onnxRuntime:
            return 6
        case .custom:
            return 7
        }
    }

    private func tagRank(_ tags: [String]) -> Int {
        if tags.contains("starter") || tags.contains("iphone-entry") {
            return 0
        }
        if tags.contains("balanced") || tags.contains("iphone-recommended") {
            return 1
        }
        if tags.contains("quality") || tags.contains("iphone-pro") {
            return 2
        }
        return 3
    }
}

private struct ModelSortKey: Comparable {
    let readyRank: Int
    let backendRank: Int
    let tagRank: Int
    let size: Int64
    let name: String

    static func < (lhs: ModelSortKey, rhs: ModelSortKey) -> Bool {
        if lhs.readyRank != rhs.readyRank {
            return lhs.readyRank < rhs.readyRank
        }
        if lhs.backendRank != rhs.backendRank {
            return lhs.backendRank < rhs.backendRank
        }
        if lhs.tagRank != rhs.tagRank {
            return lhs.tagRank < rhs.tagRank
        }
        if lhs.size != rhs.size {
            return lhs.size < rhs.size
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

enum ModelGrouping: CaseIterable, Hashable {
    case backend
    case family
    case installState
    case none

    var title: String {
        switch self {
        case .backend:
            return "Backend"
        case .family:
            return "Family"
        case .installState:
            return "State"
        case .none:
            return "None"
        }
    }

    func sections(for models: [ModelDescriptor], context: ModelListContext) -> [ModelSection] {
        switch self {
        case .backend:
            return grouped(models, title: { ModelFormatting.backendTitle($0.backend) })
        case .family:
            return grouped(models, title: { $0.family.title })
        case .installState:
            return grouped(models, title: { installTitle(for: $0, context: context) })
        case .none:
            return [ModelSection(title: "All Models", models: models)]
        }
    }

    private func grouped(_ models: [ModelDescriptor], title: (ModelDescriptor) -> String) -> [ModelSection] {
        Dictionary(grouping: models, by: title)
            .map { ModelSection(title: $0.key, models: $0.value) }
            .sorted { $0.title < $1.title }
    }

    private func installTitle(for descriptor: ModelDescriptor, context: ModelListContext) -> String {
        if context.isReadyForChat(descriptor) {
            return "Ready"
        }
        if context.installState(descriptor) != nil {
            return "Downloadable"
        }
        return "Unavailable"
    }
}
