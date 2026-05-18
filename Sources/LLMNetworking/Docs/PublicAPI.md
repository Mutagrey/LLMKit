# LLMNetworking Public API

Public API includes transport request/response, streaming transport event, and streaming parser types.

`URLSessionHTTPTransport` adapts `HTTPRequest` to `URLRequest`, sends it with an injected or default `URLSession`, and maps `HTTPURLResponse` status, headers, and body back into `HTTPResponse`.

`HTTPStreamingTransport` exposes response headers followed by body chunks through `AsyncThrowingStream<HTTPStreamEvent, Error>`. `URLSessionHTTPTransport` implements it with `URLSession.bytes(for:)` for low-latency SSE consumers.

`RetryPolicy` captures retry configuration values without executing retries itself. `AuthHeaderProvider` provides caller-supplied headers through a sendable closure.
