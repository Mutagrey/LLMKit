import Foundation

public enum HTTPMethod: String, Hashable, Sendable {
    case get = "GET"
    case post = "POST"
}

public struct HTTPRequest: Hashable, Sendable {
    public let method: HTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: Data?

    public init(method: HTTPMethod, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Hashable, Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponseHead: Hashable, Sendable {
    public let statusCode: Int
    public let headers: [String: String]

    public init(statusCode: Int, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.headers = headers
    }
}

public enum HTTPStreamEvent: Hashable, Sendable {
    case response(HTTPResponseHead)
    case body(Data)
}

public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public protocol HTTPStreamingTransport: HTTPTransport {
    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<HTTPStreamEvent, Error>
}
