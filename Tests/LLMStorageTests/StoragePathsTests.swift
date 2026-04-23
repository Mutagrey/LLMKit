import Foundation
import LLMStorage
import Testing

@Test func storagePathsBuildSessionURL() {
    let paths = StoragePaths(rootDirectory: URL(fileURLWithPath: "/tmp/llmkit"))

    #expect(paths.sessionURL(id: "abc").lastPathComponent == "abc.json")
}

@Test func manifestFileStoreSavesAndLoadsManifest() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitStorageTests")
        .appendingPathComponent(UUID().uuidString)
    let store = ManifestFileStore(directory: directory)
    let data = Data("manifest".utf8)

    try await store.saveManifest(data, named: "models.json")
    let loaded = try await store.loadManifest(named: "models.json")
    try? FileManager.default.removeItem(at: directory)

    #expect(loaded == data)
}

@Test func manifestFileStoreReturnsNilForMissingManifest() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitStorageTests")
        .appendingPathComponent(UUID().uuidString)
    let store = ManifestFileStore(directory: directory)

    let loaded = try await store.loadManifest(named: "missing.json")
    try? FileManager.default.removeItem(at: directory)

    #expect(loaded == nil)
}

@Test func atomicWriteCoordinatorCreatesParentDirectoriesAndOverwrites() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitStorageTests")
        .appendingPathComponent(UUID().uuidString)
    let fileURL = directory
        .appendingPathComponent("nested", isDirectory: true)
        .appendingPathComponent("manifest.json")
    let coordinator = AtomicWriteCoordinator()

    try coordinator.write(Data("first".utf8), to: fileURL)
    try coordinator.write(Data("second".utf8), to: fileURL)
    let loaded = try Data(contentsOf: fileURL)
    try? FileManager.default.removeItem(at: directory)

    #expect(loaded == Data("second".utf8))
}
