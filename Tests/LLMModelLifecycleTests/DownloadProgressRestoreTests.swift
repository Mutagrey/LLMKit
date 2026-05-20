import Foundation
import LLMCore
import Testing
@testable import LLMModelLifecycle

private struct SnapshotPrimingDownloader: ProgressReportingModelArtifactDownloading {
    let expectedByteCount: Int64
    let checkpoint: Int64

    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        try await download(artifact, to: destination) { _ in }
    }

    func download(
        _ artifact: ModelArtifact,
        to destination: URL,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) async throws -> ModelArtifactDownloadResult {
        await onProgress(ModelArtifactDownloadProgress(
            artifactID: artifact.id,
            bytesWritten: checkpoint,
            expectedTotalBytes: expectedByteCount
        ))
        throw LLMError.cancelled
    }
}

private struct RestartedProgressDownloader: ProgressReportingModelArtifactDownloading {
    let expectedByteCount: Int64
    let checkpoints: [Int64]

    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        try await download(artifact, to: destination) { _ in }
    }

    func download(
        _ artifact: ModelArtifact,
        to destination: URL,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) async throws -> ModelArtifactDownloadResult {
        for checkpoint in checkpoints {
            await onProgress(ModelArtifactDownloadProgress(
                artifactID: artifact.id,
                bytesWritten: checkpoint,
                expectedTotalBytes: expectedByteCount
            ))
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x61, count: Int(expectedByteCount)).write(to: destination, options: [.atomic])
        return ModelArtifactDownloadResult(artifactID: artifact.id, bytesWritten: expectedByteCount)
    }
}

@Test func modelInstallCoordinatorRestoresStateFromProgressSnapshot() async throws {
    let rootDirectory = temporaryRootDirectory()
    let descriptor = progressRestoreDescriptor(id: "mlx/progress-state-restore")
    try await primeProgressSnapshot(rootDirectory: rootDirectory, descriptor: descriptor)
    let restoredCoordinator = ModelInstallCoordinator(artifactRootDirectory: rootDirectory)

    #expect(try await restoredCoordinator.state(for: descriptor.id) == .paused(progress: 0.25))
}

@Test func restartedInstallPublishesRestoredProgressBeforeDownloading() async throws {
    let rootDirectory = temporaryRootDirectory()
    let descriptor = progressRestoreDescriptor(id: "mlx/progress-start-restore")
    try await primeProgressSnapshot(rootDirectory: rootDirectory, descriptor: descriptor)
    let restoredCoordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: RestartedProgressDownloader(expectedByteCount: 1_000, checkpoints: [300, 1_000])
    )

    var downloadingStates: [InstallState] = []
    var progressDetails: [ModelInstallProgress] = []
    for try await event in restoredCoordinator.install(descriptor) {
        switch event {
        case .stateChanged(_, let state):
            if case .downloading = state {
                downloadingStates.append(state)
            }
        case .progressDetail(_, let detail):
            progressDetails.append(detail)
        case .progress, .completed, .failed:
            break
        }
    }

    #expect(downloadingStates.first == .downloading(progress: 0.25))
    #expect(progressDetails.first?.fractionCompleted == 0.25)
    #expect(!downloadingStates.contains(.downloading(progress: 0)))
}

@Test func resumedDownloadProgressAddsBaselineOnlyForRelativeCallbacks() async throws {
    let rootDirectory = temporaryRootDirectory()
    let descriptor = progressRestoreDescriptor(id: "mlx/progress-relative-resume")
    try await primeProgressSnapshot(rootDirectory: rootDirectory, descriptor: descriptor)
    let restoredCoordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: RestartedProgressDownloader(expectedByteCount: 1_000, checkpoints: [100, 260, 1_000])
    )

    var fractions: [Double] = []
    var completedBytes: [Int64] = []
    for try await event in restoredCoordinator.install(descriptor) {
        guard case .progressDetail(_, let detail) = event else {
            continue
        }
        fractions.append(detail.fractionCompleted)
        if let bytes = detail.completedBytes {
            completedBytes.append(bytes)
        }
    }

    #expect(fractions == fractions.sorted())
    #expect(completedBytes.contains(250))
    #expect(completedBytes.contains(350))
    #expect(completedBytes.contains(510))
    #expect(completedBytes.last == 1_000)
}

@Test func resumedDownloadProgressDoesNotAddBaselineForAbsoluteCallbacks() async throws {
    let rootDirectory = temporaryRootDirectory()
    let descriptor = progressRestoreDescriptor(id: "mlx/progress-absolute-resume")
    try await primeProgressSnapshot(rootDirectory: rootDirectory, descriptor: descriptor)
    let restoredCoordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: RestartedProgressDownloader(expectedByteCount: 1_000, checkpoints: [300, 600, 1_000])
    )

    var completedBytes: [Int64] = []
    for try await event in restoredCoordinator.install(descriptor) {
        guard case .progressDetail(_, let detail) = event, let bytes = detail.completedBytes else {
            continue
        }
        completedBytes.append(bytes)
    }

    #expect(completedBytes.contains(250))
    #expect(completedBytes.contains(300))
    #expect(completedBytes.contains(600))
    #expect(!completedBytes.contains(550))
    #expect(!completedBytes.contains(850))
    #expect(completedBytes.last == 1_000)
}

private func primeProgressSnapshot(rootDirectory: URL, descriptor: ModelDescriptor) async throws {
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: SnapshotPrimingDownloader(expectedByteCount: 1_000, checkpoint: 250)
    )

    do {
        for try await _ in coordinator.install(descriptor) {}
        Issue.record("Expected priming install to cancel.")
    } catch let error as LLMError {
        #expect(error == .cancelled)
    }
}

private func progressRestoreDescriptor(id: ModelID) -> ModelDescriptor {
    ModelDescriptor(
        id: id,
        displayName: id.rawValue,
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    byteCount: 1_000
                )
            ]
        )
    )
}

private func temporaryRootDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
}
