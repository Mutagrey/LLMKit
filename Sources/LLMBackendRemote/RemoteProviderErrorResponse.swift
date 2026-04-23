import Foundation

struct RemoteProviderErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let type: String?
        let message: String?
        let code: String?
        let param: String?
    }

    let error: ErrorBody?
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case error
        case requestID = "request_id"
    }

    var message: String? {
        error?.message
    }
}

enum RemoteProviderErrorMapper {
    static func message(
        statusCode: Int,
        headers: [String: String],
        body: Data,
        decoder: JSONDecoder
    ) -> String {
        guard
            let errorResponse = try? decoder.decode(RemoteProviderErrorResponse.self, from: body),
            let errorBody = errorResponse.error
        else {
            return "HTTP \(statusCode)"
        }

        let message = errorBody.message ?? "Provider request failed."
        var details: [String] = []
        if let type = errorBody.type, !type.isEmpty {
            details.append("type=\(type)")
        }
        if let code = errorBody.code, !code.isEmpty {
            details.append("code=\(code)")
        }
        if let param = errorBody.param, !param.isEmpty {
            details.append("param=\(param)")
        }
        if let requestID = errorResponse.requestID ?? requestID(from: headers) {
            details.append("request_id=\(requestID)")
        }

        guard !details.isEmpty else {
            return "HTTP \(statusCode): \(message)"
        }
        return "HTTP \(statusCode): \(message) (\(details.joined(separator: ", ")))"
    }

    private static func requestID(from headers: [String: String]) -> String? {
        headerValue(named: "x-request-id", in: headers) ??
            headerValue(named: "request-id", in: headers)
    }

    private static func headerValue(named name: String, in headers: [String: String]) -> String? {
        headers.first { key, _ in key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}
