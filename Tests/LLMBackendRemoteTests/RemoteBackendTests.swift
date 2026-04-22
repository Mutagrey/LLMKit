import Foundation
import LLMBackendRemote
import LLMCore
import Testing

@Test func remoteConfigurationStoresProviderID() throws {
    let url = try #require(URL(string: "https://example.com"))
    let configuration = RemoteConfiguration(providerID: "test", baseURL: url)

    #expect(configuration.providerID.rawValue == "test")
}
