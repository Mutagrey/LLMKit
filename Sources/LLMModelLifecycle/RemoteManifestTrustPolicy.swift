import Foundation
import LLMCore

public struct RemoteManifestTrustPolicy: Hashable, Sendable {
    public let requiresHTTPS: Bool
    public let allowedHosts: Set<String>
    public let trustedSigningPublicKeys: Set<String>

    public init(
        requiresHTTPS: Bool = true,
        allowedHosts: Set<String> = [],
        trustedSigningPublicKeys: Set<String> = []
    ) {
        self.requiresHTTPS = requiresHTTPS
        self.allowedHosts = Set(allowedHosts.map(Self.normalizeHost))
        self.trustedSigningPublicKeys = Set(trustedSigningPublicKeys.map(Self.normalizeKey))
    }

    public static let `default` = RemoteManifestTrustPolicy()

    func validate(url: URL, signature: ModelManifestSignature) throws {
        if requiresHTTPS, url.scheme?.lowercased() != "https" {
            throw LLMError.verificationFailed("Remote model catalogs require HTTPS.")
        }

        if !allowedHosts.isEmpty {
            guard let host = url.host.map(Self.normalizeHost), allowedHosts.contains(host) else {
                throw LLMError.verificationFailed("Remote model catalog host is not allowlisted.")
            }
        }

        if !trustedSigningPublicKeys.isEmpty {
            guard let publicKeyValue = signature.publicKeyValue.map(Self.normalizeKey),
                  trustedSigningPublicKeys.contains(publicKeyValue) else {
                throw LLMError.verificationFailed("Remote model catalog signing key is not trusted.")
            }
        }
    }

    private static func normalizeHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
