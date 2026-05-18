import Foundation
import LLMCore
@preconcurrency import CLlama

private enum LlamaCppNativeError: Error {
    case couldNotInitializeModel(String)
    case couldNotInitializeContext
    case promptExceedsContext(required: Int, context: Int)
    case decodeFailed
}

private func llamaBatchClear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

private func llamaBatchAdd(
    _ batch: inout llama_batch,
    _ id: llama_token,
    _ position: llama_pos,
    _ sequenceIDs: [llama_seq_id],
    _ logits: Bool
) {
    batch.token[Int(batch.n_tokens)] = id
    batch.pos[Int(batch.n_tokens)] = position
    batch.n_seq_id[Int(batch.n_tokens)] = Int32(sequenceIDs.count)
    for index in 0..<sequenceIDs.count {
        batch.seq_id[Int(batch.n_tokens)]![index] = sequenceIDs[index]
    }
    batch.logits[Int(batch.n_tokens)] = logits ? 1 : 0
    batch.n_tokens += 1
}

private enum LlamaCppBackendLifecycle {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var referenceCount = 0

    static func retain() {
        lock.withLock {
            if referenceCount == 0 {
                llama_backend_init()
            }
            referenceCount += 1
        }
    }

    static func release() {
        lock.withLock {
            guard referenceCount > 0 else {
                return
            }
            referenceCount -= 1
            if referenceCount == 0 {
                llama_backend_free()
            }
        }
    }
}

actor LlamaCppNativeContext {
    static var isAvailable: Bool { true }

    private let storage: LlamaCppNativeStorage
    private var tokens: [llama_token] = []
    private var pendingUTF8Bytes: [CChar] = []
    private var isDone = false
    private var currentPosition: Int32 = 0
    private var generationLimit: Int32

    private init(
        storage: LlamaCppNativeStorage,
        generationLimit: Int32
    ) {
        self.storage = storage
        self.generationLimit = generationLimit
    }
    static func create(path: String, configuration: LlamaCppRuntimeConfiguration) throws -> LlamaCppNativeContext {
        LlamaCppBackendLifecycle.retain()
        do {
            return try createRetainedContext(path: path, configuration: configuration)
        } catch {
            LlamaCppBackendLifecycle.release()
            throw error
        }
    }

    private static func createRetainedContext(
        path: String,
        configuration: LlamaCppRuntimeConfiguration
    ) throws -> LlamaCppNativeContext {
        var modelParameters = llama_model_default_params()
        if configuration.useMetal {
            modelParameters.n_gpu_layers = 99
        } else {
            modelParameters.n_gpu_layers = 0
        }
        #if targetEnvironment(simulator)
        modelParameters.n_gpu_layers = 0
        #endif

        guard let model = llama_model_load_from_file(path, modelParameters) else {
            throw LlamaCppNativeError.couldNotInitializeModel(path)
        }

        let defaultThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        let threads = Int32(configuration.threadCount ?? defaultThreads)
        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = UInt32(configuration.contextSize)
        contextParameters.n_batch = UInt32(configuration.batchSize)
        contextParameters.n_threads = threads
        contextParameters.n_threads_batch = threads

        guard let context = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            throw LlamaCppNativeError.couldNotInitializeContext
        }

        return LlamaCppNativeContext(
            storage: LlamaCppNativeStorage(model: model, context: context),
            generationLimit: Int32(configuration.contextSize)
        )
    }

    func stream(prompt: String, maxTokens: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try startCompletion(prompt: prompt, maxTokens: maxTokens)
                    while !Task.isCancelled {
                        let delta = try nextToken()
                        if !delta.isEmpty {
                            continuation.yield(delta)
                        }
                        if finished {
                            break
                        }
                    }
                    if Task.isCancelled {
                        throw CancellationError()
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

    private var finished: Bool {
        isDone
    }

    private func startCompletion(prompt: String, maxTokens: Int?) throws {
        tokens = tokenize(text: prompt, addBOS: true)
        pendingUTF8Bytes = []
        isDone = false
        llama_memory_clear(llama_get_memory(storage.context), true)
        llama_sampler_reset(storage.sampler)
        let contextSize = llama_n_ctx(storage.context)
        let requestedTokens = tokens.count + min(maxTokens ?? Int(contextSize), Int(contextSize))
        if requestedTokens > contextSize {
            throw LlamaCppNativeError.promptExceedsContext(required: requestedTokens, context: Int(contextSize))
        }
        generationLimit = Int32(min(requestedTokens, Int(contextSize)))

        llamaBatchClear(&storage.batch)
        for index in tokens.indices {
            llamaBatchAdd(&storage.batch, tokens[index], Int32(index), [0], false)
        }
        storage.batch.logits[Int(storage.batch.n_tokens) - 1] = 1

        guard llama_decode(storage.context, storage.batch) == 0 else {
            throw LlamaCppNativeError.decodeFailed
        }

        currentPosition = storage.batch.n_tokens
    }

    private func nextToken() throws -> String {
        let tokenID = llama_sampler_sample(storage.sampler, storage.context, storage.batch.n_tokens - 1)
        if llama_vocab_is_eog(storage.vocab, tokenID) || currentPosition >= generationLimit {
            isDone = true
            let trailingText = decodeUTF8(pendingUTF8Bytes)
            pendingUTF8Bytes.removeAll()
            return trailingText
        }

        pendingUTF8Bytes.append(contentsOf: tokenToPiece(token: tokenID))
        let text: String
        if let validText = validateUTF8(pendingUTF8Bytes) {
            pendingUTF8Bytes.removeAll()
            text = validText
        } else if pendingUTF8Bytes.indices.contains(where: { index in
            index != 0 && validateUTF8(Array(pendingUTF8Bytes.suffix(index))) != nil
        }) {
            text = decodeUTF8(pendingUTF8Bytes)
            pendingUTF8Bytes.removeAll()
        } else {
            text = ""
        }

        llamaBatchClear(&storage.batch)
        llamaBatchAdd(&storage.batch, tokenID, currentPosition, [0], true)
        currentPosition += 1

        guard llama_decode(storage.context, storage.batch) == 0 else {
            throw LlamaCppNativeError.decodeFailed
        }
        return text
    }

    private func tokenize(text: String, addBOS: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let tokenCapacity = utf8Count + (addBOS ? 1 : 0) + 1
        let tokenBuffer = UnsafeMutablePointer<llama_token>.allocate(capacity: tokenCapacity)
        defer { tokenBuffer.deallocate() }

        let tokenCount = llama_tokenize(
            storage.vocab,
            text,
            Int32(utf8Count),
            tokenBuffer,
            Int32(tokenCapacity),
            addBOS,
            false
        )

        guard tokenCount > 0 else {
            return []
        }

        return (0..<Int(tokenCount)).map { tokenBuffer[$0] }
    }

    private func tokenToPiece(token: llama_token) -> [CChar] {
        let initialCapacity = 8
        let initialBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: initialCapacity)
        initialBuffer.initialize(repeating: 0, count: initialCapacity)
        defer { initialBuffer.deallocate() }

        let pieceLength = llama_token_to_piece(storage.vocab, token, initialBuffer, Int32(initialCapacity), 0, false)
        if pieceLength >= 0 {
            return Array(UnsafeBufferPointer(start: initialBuffer, count: Int(pieceLength)))
        }

        let requiredCapacity = Int(-pieceLength)
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: requiredCapacity)
        buffer.initialize(repeating: 0, count: requiredCapacity)
        defer { buffer.deallocate() }

        let copiedLength = llama_token_to_piece(storage.vocab, token, buffer, Int32(requiredCapacity), 0, false)
        return Array(UnsafeBufferPointer(start: buffer, count: max(0, Int(copiedLength))))
    }

    private func decodeUTF8(_ bytes: [CChar]) -> String {
        String(decoding: unsignedBytes(bytes), as: UTF8.self)
    }

    private func validateUTF8(_ bytes: [CChar]) -> String? {
        String(validating: unsignedBytes(bytes), as: UTF8.self)
    }

    private func unsignedBytes(_ bytes: [CChar]) -> [UInt8] {
        bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    }
}

private final class LlamaCppNativeStorage: @unchecked Sendable {
    let model: OpaquePointer
    let context: OpaquePointer
    let vocab: OpaquePointer
    let sampler: UnsafeMutablePointer<llama_sampler>
    var batch: llama_batch

    init(model: OpaquePointer, context: OpaquePointer) {
        self.model = model
        self.context = context
        self.vocab = llama_model_get_vocab(model)
        self.sampler = llama_sampler_chain_init(llama_sampler_chain_default_params())
        self.batch = llama_batch_init(512, 0, 1)
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.4))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 1...UInt32.max)))
    }

    deinit {
        llama_sampler_free(sampler)
        llama_batch_free(batch)
        llama_free(context)
        llama_model_free(model)
        LlamaCppBackendLifecycle.release()
    }
}
