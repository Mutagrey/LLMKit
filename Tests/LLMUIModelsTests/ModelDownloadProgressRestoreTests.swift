import Foundation
import LLMCore
import LLMModelLifecycle
import LLMUIModels
import Testing

private actor UIProgressLog {
    private(set) var didReportProgress = false

    func recordProgress() {
        didReportProgress = true
    }
}

private struct UISnapshotPrimingDownloader: ProgressReportingModelArtifactDownloading {
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
            bytesWritten: 250,
            expectedTotalBytes: 1_000
        ))
        throw LLMError.cancelled
    }
}

private struct UIBlockingRelativeProgressDownloader: ProgressReportingModelArtifactDownloading {
    let log: UIProgressLog

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
            bytesWritten: 100,
            expectedTotalBytes: 1_000
        ))
        await log.recordProgress()
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return ModelArtifactDownloadResult(artifactID: artifact.id, bytesWritten: 1_000)
    }
}

@MainActor
@Test func downloadsViewModelKeepsRestoredProgressWhenInstallRestarts() async throws {
    let rootDirectory = temporaryRootDirectory()
    let descriptor = progressRestoreDescriptor(id: "mlx/ui-progress-restore")
    try await primeProgressSnapshot(rootDirectory: rootDirectory, descriptor: descriptor)
    let log = UIProgressLog()
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: UIBlockingRelativeProgressDownloader(log: log)
    )
    let viewModel = ModelDownloadsViewModel(descriptors: [descriptor], lifecycleService: coordinator)

    await viewModel.refresh()

    #expect(viewModel.installState(for: descriptor.id) == .paused(progress: 0.25))
    #expect(viewModel.progressDetail(for: descriptor.id)?.completedBytes == 250)

    await viewModel.beginInstall(descriptor)
    for _ in 0..<100 {
        if await log.didReportProgress {
            break
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    #expect(await log.didReportProgress)
    #expect((viewModel.progress(for: descriptor.id) ?? 0) >= 0.25)
    #expect(viewModel.progressDetail(for: descriptor.id)?.completedBytes ?? 0 >= 250)

    await viewModel.cancelInstall(descriptor.id)
}

private func primeProgressSnapshot(rootDirectory: URL, descriptor: ModelDescriptor) async throws {
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: UISnapshotPrimingDownloader()
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
