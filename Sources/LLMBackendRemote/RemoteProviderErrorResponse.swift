import Foundation

struct RemoteProviderErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let message: String?
    }

    let error: ErrorBody?

    var message: String? {
        error?.message
    }
}
