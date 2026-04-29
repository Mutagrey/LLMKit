import Foundation
import LLMCore
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

@Test func sessionFileStorePersistsSnapshotsAndIndex() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitStorageTests")
        .appendingPathComponent(UUID().uuidString)
    let store = SessionFileStore(paths: StoragePaths(rootDirectory: directory))
    let snapshot = SessionSnapshot(
        id: "session-1",
        descriptor: SessionDescriptor(id: "session-1", title: "Stored chat"),
        messages: [ChatMessage(role: .user, content: MessageContent(text: "hello"))],
        executionRequirements: ExecutionRequirements(requiredCapabilities: [.chat])
    )

    try await store.saveSession(snapshot)
    let loaded = try await store.loadSession(id: snapshot.id)
    let overviews = try await store.listSessions()
    try? FileManager.default.removeItem(at: directory)

    #expect(loaded == snapshot)
    #expect(overviews.count == 1)
    #expect(overviews.first?.title == "Stored chat")
}

@Test func sessionFileStoreRebuildsIndexFromSnapshotsWhenIndexIsMissing() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitStorageTests")
        .appendingPathComponent(UUID().uuidString)
    let paths = StoragePaths(rootDirectory: directory)
    let store = SessionFileStore(paths: paths)
    let snapshot = SessionSnapshot(
        id: "session-2",
        descriptor: SessionDescriptor(id: "session-2", title: "Cold start"),
        messages: [ChatMessage(role: .assistant, content: MessageContent(text: "restored"))]
    )
    let encoder = JSONEncoder()
    try FileManager.default.createDirectory(at: paths.sessionsDirectory, withIntermediateDirectories: true)
    try encoder.encode(snapshot).write(to: paths.sessionURL(id: snapshot.id), options: [.atomic])

    let overviews = try await store.listSessions()
    let rebuiltIndexData = try Data(contentsOf: paths.sessionIndexURL)
    let rebuiltIndex = try JSONDecoder().decode([SessionOverview].self, from: rebuiltIndexData)
    try? FileManager.default.removeItem(at: directory)

    #expect(overviews.map { $0.id } == [snapshot.id])
    #expect(rebuiltIndex.map { $0.id } == [snapshot.id])
}
