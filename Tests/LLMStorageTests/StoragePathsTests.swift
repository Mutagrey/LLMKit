import Foundation
import LLMStorage
import Testing

@Test func storagePathsBuildSessionURL() {
    let paths = StoragePaths(rootDirectory: URL(fileURLWithPath: "/tmp/llmkit"))

    #expect(paths.sessionURL(id: "abc").lastPathComponent == "abc.json")
}
