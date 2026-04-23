import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LLMNetworking
import Testing

@Suite(.serialized)
struct URLSessionHTTPTransportTests {
    @Test func urlSessionTransportSendsHTTPRequestAndMapsHTTPResponse() async throws {
        let url = try #require(URL(string: "https://example.com/v1/messages"))
        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://example.com/v1/messages")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
            #expect(bodyData(from: request) == Data(#"{"hello":"world"}"#.utf8))

            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["x-request-id": "req-123"]
            ))
            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let transport = URLSessionHTTPTransport(configuration: configuration)
        let response = try await transport.send(HTTPRequest(
            method: .post,
            url: url,
            headers: ["Authorization": "Bearer token"],
            body: Data(#"{"hello":"world"}"#.utf8)
        ))

        #expect(response.statusCode == 201)
        #expect(response.headers["x-request-id"] == "req-123")
        #expect(String(data: response.body, encoding: .utf8) == #"{"ok":true}"#)
    }

    @Test func urlSessionTransportPropagatesTransportErrors() async throws {
        let url = try #require(URL(string: "https://example.com/fail"))
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let transport = URLSessionHTTPTransport(configuration: configuration)

        do {
            _ = try await transport.send(HTTPRequest(method: .get, url: url))
            Issue.record("Expected URLSessionHTTPTransport to propagate URL loading errors.")
        } catch {
            #expect((error as? URLError)?.code == .notConnectedToInternet)
        }
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler?(request) ?? {
                throw URLError(.badServerResponse)
            }()
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func bodyData(from request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }
    guard let stream = request.httpBodyStream else {
        return nil
    }
    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: bufferSize)
        if count <= 0 {
            break
        }
        data.append(buffer, count: count)
    }
    return data
}
