//
//  LLaMACPP.swift
//  LLaMA Playground
//
//  Created by Jed Fox on 2023-03-11.
//

import Foundation
import SwiftUI
import llama

class LLaMAInvoker: ObservableObject {
    @Published var status = Status.missingModel
    @Published var loadingModel = false

    @Published private var ctx: OpaquePointer!
    private var modelLoaded = false
    private var savedTokens: [llama_token] = []

    var contextLength: Int32 {
        if let ctx {
            return llama_n_ctx(ctx)
        } else {
            return 512
        }
    }

    static let shared = LLaMAInvoker()

    private init() {
        #if os(iOS)
        print("Available memory: \(os_proc_available_memory().formatted(.byteCount(style: .memory)))")
        #endif
    }

    let safeTokens = [llama_token_nl()]

    func loadModel(at url: URL, f16: Bool) {
        guard !loadingModel else { return }
        loadingModel = true
        savedTokens = []
        self.status = .starting
        DispatchQueue.global().async {
            if self.modelLoaded {
                llama_free(self.ctx)
                Task { @MainActor in
                    self.ctx = nil
                }
            }

            var params = llama_context_default_params()
            params.n_ctx = 2048
            params.seed = -1
            params.f16_kv = f16
            let ctx = url.withUnsafeFileSystemRepresentation { path in
                llama_init_from_file(path, params)
            }
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(100))
                self.ctx = ctx
                if ctx != nil {
                    self.status = .idle
                    self.modelLoaded = true
                } else {
                    self.status = .missingModel
                }
                self.loadingModel = false
            }
        }
    }
    deinit {
        llama_free(ctx)
    }

    enum Status: Hashable {
        case missingModel
        case starting
        case idle
        case working(Task<Void, Never>)
        case progress(Task<Void, Never>, Response)
        case done(Response)
        case failed(WrappedError)

        var response: Response? {
            if case .progress(_, let response) = self {
                return response
            }
            if case .done(let response) = self {
                return response
            }
            return nil
        }

        var isDone: Bool {
            if case .done = self {
                return true
            }
            if case .failed = self {
                return true
            }
            return false
        }

        struct Response: Hashable {
            let prompt: String
            let result: String
            let duration: TimeInterval?
            let finishReason: FinishReason?
            let tokens: Int

            enum FinishReason: Hashable {
                case endOfText
                case cancelled
                case limit
            }
        }

        final class WrappedError: Hashable {
            let error: Error
            init(_ error: Error) {
                self.error = error
            }

            static func == (lhs: WrappedError, rhs: WrappedError) -> Bool {
                lhs === rhs
            }
            func hash(into hasher: inout Hasher) {
                hasher.combine(ObjectIdentifier(self))
            }
        }
    }

    func complete(_ request: Configuration, openURL: OpenURLAction) {
        if case .working = status {
            assertionFailure()
        }
        status = .working(Task {
            do {
                try await callAPI(request: request)
                // todo: ???
            } catch {
                if error is CancellationError {
                    if case let .progress(_, response) = status {
                        await MainActor.run {
                            status = .done(.init(
                                prompt: response.prompt,
                                result: response.result,
                                duration: response.duration,
                                finishReason: .cancelled,
                                tokens: response.tokens
                            ))
                        }
                        return
                    } else {
                        print("unexpected cancellation!")
                    }
                }
                print(error)
                status = .failed(Status.WrappedError(error))
            }
        })
    }

    func stop() {
        if case .working(let task) = status {
            task.cancel()
        }
        if case .progress(let task, _) = status {
            task.cancel()
        }
    }

    func callAPI(request config: Configuration) async throws {
        func response(_ reason: Status.Response.FinishReason?) -> Status.Response {
            .init(
                prompt: config.prompt,
                result: looseString(output),
                duration: Date().timeIntervalSince(start),
                finishReason: reason,
                tokens: tokens.count
            )
        }

        func process(_ token: llama_token) async {
            tokens.append(token)
            savedTokens.append(token)
            output.append(contentsOf: sequence(state: llama_token_to_str(ctx, token), next: { ptr in
                if ptr.pointee != 0 {
                    let char = ptr.pointee
                    ptr += 1
                    return char
                }
                return nil
            }))

            await Task { @MainActor [response] in
                switch self.status {
                case .working(let task), .progress(let task, _):
                    self.status = .progress(task, response(nil))
                default:
                    print("Invalid status!", self.status)
                }
            }.value
        }

        var tokens: [llama_token] = []
        var output: [CChar] = []
        let start = Date()

        let promptTokens = await runBlocking { [ctx] in
            Array<llama_token>(unsafeUninitializedCapacity: config.prompt.utf8.count) { buffer, initializedCount in
                initializedCount = Int(llama_tokenize(ctx, config.prompt, buffer.baseAddress, Int32(buffer.count), true))
            }
        }

        // always evaluate last token, since otherwise really weird things happen
        let common = max(0, zip(promptTokens, savedTokens).prefix(while: ==).count - 1)
        savedTokens = []

        for i in 0..<common {
            await process(promptTokens[i])
        }

        print("skipped \(common) tokens: \(tokens.count)")

        for var chunk in promptTokens.dropFirst(common).chunks(maxLength: config.batchSize) {
//            print("llama_eval(ctx, &[\(chunk.map(String.init).joined(separator: ", "))], \(chunk.count), \(tokens.count), \(config.threads))")
            try Task.checkCancellation()
            let ok = await runBlocking { [ctx] in
                llama_eval(ctx, &chunk, Int32(chunk.count), Int32(tokens.count), config.threads)
            }
            if ok != 0 {
                throw LLaMAError.evalFailed
            }
            for token in chunk {
                await process(token)
            }
        }

        try Task.checkCancellation()

        var mirostat_µ = Float(2 * config.mirostatTargetEntropy)
        while tokens.count < config.tokens - 1 {
            var token = await runBlocking { [ctx] in
                let logits = llama_get_logits(ctx)!
                var candidatesArray = (0..<llama_n_vocab(ctx)).map { tokenId in
                    llama_token_data(id: tokenId, logit: logits[Int(tokenId)], p: 0)
                }
                return candidatesArray.withUnsafeMutableBufferPointer { ptr in
                    var candidates = llama_token_data_array(data: ptr.baseAddress, size: ptr.count, sorted: false)
                    let savedLogits = self.safeTokens.map { logits[Int($0)] }

                    tokens.suffix(config.repeatWindow).withUnsafeBufferPointer { ptr in
                        llama_sample_repetition_penalty(ctx, &candidates, ptr.baseAddress, ptr.count, Float(config.repeatPenalty))
                        llama_sample_frequency_and_presence_penalties(ctx, &candidates, ptr.baseAddress, ptr.count, Float(config.frequencyPenalty), Float(config.presencePenalty))
                    }

                    zip(self.safeTokens, savedLogits).forEach { logits[Int($0)] = $1 }

                    let mirostat_m = 100
                    switch config.sampler {
                    case .greedy:
                        return llama_sample_token_greedy(ctx, &candidates)
                    case .mirostatV1:
                        llama_sample_temperature(ctx, &candidates, Float(config.temperature))
                        return llama_sample_token_mirostat(ctx, &candidates, Float(config.mirostatTargetEntropy), Float(config.mirostatLearningRate), Int32(mirostat_m), &mirostat_µ)
                    case .mirostatV2:
                        llama_sample_temperature(ctx, &candidates, Float(config.temperature))
                        return llama_sample_token_mirostat_v2(ctx, &candidates, Float(config.mirostatTargetEntropy), Float(config.mirostatLearningRate), &mirostat_µ)
                    case .classic:
                        llama_sample_top_k(ctx, &candidates, Int32(config.topK), 1)
                        llama_sample_tail_free(ctx, &candidates, Float(config.tfsZ), 1)
                        llama_sample_typical(ctx, &candidates, Float(config.typicalP), 1)
                        llama_sample_top_p(ctx, &candidates, Float(config.topP), 1)
                        llama_sample_temperature(ctx, &candidates, Float(config.temperature))
                        return llama_sample_token(ctx, &candidates)
                    }
                }
            }
            await process(token)

            try Task.checkCancellation()
            await runBlocking {
                _ = llama_eval(self.ctx, &token, 1, Int32(tokens.count), config.threads)
            }
            try Task.checkCancellation()

            if token == llama_token_eos() {
                let status = Status.done(response(.endOfText))
                await MainActor.run {
                    self.status = status
                }
                return
            }
        }

        let status = Status.done(response(.limit))
        await MainActor.run {
            self.status = status
        }
    }
}

extension Sequence {
    func chunks(maxLength: Int) -> some Sequence<[Element]> {
        AnySequence {
            ChunkIterator(iterator: makeIterator(), maxLength: maxLength)
        }
    }
}

private class ChunkIterator<I: IteratorProtocol>: IteratorProtocol {
    private var iterator: I
    private let maxLength: Int

    init(iterator: I, maxLength: Int) {
        self.iterator = iterator
        self.maxLength = maxLength
    }

    func next() -> [I.Element]? {
        var result: [I.Element] = []
        while result.count < maxLength, let element = iterator.next() {
            result.append(element)
        }
        if result.isEmpty {
            return nil
        }
        return result
    }
}

private let q = DispatchQueue(label: "llama")

private func runBlocking<T>(_ cb: @escaping () -> T) async -> T {
    await withCheckedContinuation { continuation in
        q.async {
            continuation.resume(returning: cb())
        }
    }
}

class ClosureWrapper {
    typealias Handler = (Float) -> Void
    private let ptr = UnsafeMutablePointer<Handler>.allocate(capacity: 1)
    init(_ closure: @escaping Handler) {
        ptr.initialize(to: closure)
    }

    var ctx: UnsafeMutableRawPointer {
        .init(ptr)
    }

    var handler: llama_progress_callback {
        { progress, ptr in
            let closurePointer = ptr?.assumingMemoryBound(to: Handler.self)
            closurePointer?.pointee(progress)
        }
    }

    deinit {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }
}

//extension gpt_params {
//    init(_ config: Configuration) {
//        self.init()
////        n_threads = Int32(config.threads)
//        n_predict = Int32(config.tokens)
//        top_k = Int32(config.topK)
//        top_p = Float(config.topP)
//        temp = Float(config.temperature)
//        n_batch = Int32(config.batchSize)
//        prompt = bridge_string(config.prompt)
//        seed = config.seed
//        repeat_last_n = Int32(config.repeatWindow)
//        repeat_penalty = Float(config.repeatPenalty)
////        n_threads = 8
//    }
//}

func looseString(_ bytes: [CChar]) -> String {
    return String(cString: bytes + [0])
}

enum LLaMAError: Error {
    case evalFailed
}
