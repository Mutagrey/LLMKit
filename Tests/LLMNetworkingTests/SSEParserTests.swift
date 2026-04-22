import LLMNetworking
import Testing

@Test func sseParserParsesDataBlocks() {
    let events = SSEParser().parse("event: message\ndata: hello\n\n")

    #expect(events == [SSEEvent(event: "message", data: "hello")])
}
