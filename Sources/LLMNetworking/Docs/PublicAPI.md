# LLMNetworking Public API

Public API includes transport request/response and streaming parser types.

`URLSessionHTTPTransport` adapts `HTTPRequest` to `URLRequest`, sends it with an injected or default `URLSession`, and maps `HTTPURLResponse` status, headers, and body back into `HTTPResponse`.

`RetryPolicy` captures retry configuration values without executing retries itself. `AuthHeaderProvider` provides caller-supplied headers through a sendable closure.
