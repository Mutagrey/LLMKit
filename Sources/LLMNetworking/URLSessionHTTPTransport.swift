import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public init(configuration: URLSessionConfiguration) {
        self.session = URLSession(configuration: configuration)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = makeURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers(from: httpResponse),
            body: data
        )
    }

    private func makeURLRequest(from request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        return urlRequest
    }

    private func headers(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [:]) { headers, pair in
            guard
                let field = pair.key as? String,
                let value = pair.value as? CustomStringConvertible
            else {
                return
            }
            headers[field] = value.description
        }
    }
}
