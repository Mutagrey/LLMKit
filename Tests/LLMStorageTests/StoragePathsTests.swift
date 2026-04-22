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
