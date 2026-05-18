import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct URLSessionHTTPTransport: HTTPStreamingTransport {
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

    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<HTTPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = makeURLRequest(from: request)
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    continuation.yield(.response(HTTPResponseHead(
                        statusCode: httpResponse.statusCode,
                        headers: headers(from: httpResponse)
                    )))

                    var buffer = Data()
                    buffer.reserveCapacity(4_096)
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        buffer.append(byte)
                        if buffer.count >= 4_096 {
                            continuation.yield(.body(buffer))
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(.body(buffer))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
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
