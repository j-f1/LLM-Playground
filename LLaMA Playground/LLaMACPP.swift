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
    private var shouldStop = false

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

    func loadModel(at url: URL, params: llama_context_params = llama_context_default_params()) {
        guard !loadingModel else { return }
        loadingModel = true
        DispatchQueue.global().async {
//            _ = llama_bootstrap(URL.documentsDirectory.appendingPathComponent("7b-q4_0.bin").path(percentEncoded: false), &self.state) { progress in
//            _ = llama_bootstrap(Bundle.main.path(forResource: "7b-q4_0", ofType: "bin"), &self.state) { progress in
//            _ = llama_bootstrap("/Users/jed/Documents/iOS/GPT-3 Playground/7b-q4_0.bin", &self.state) { progress in
//            _ = llama_bootstrap("/Users/jed/Documents/github-clones/llama.cpp/13b-q4_0.bin", &self.state) { progress in
            if self.modelLoaded {
                llama_free(self.ctx)
            }
            let progressHandler = ClosureWrapper { progress in
                Task { @MainActor in
                    self.status = .starting(progress)
                }
            }

            let ctx = llama_init_from_file(url.path(percentEncoded: false), params, progressHandler.handler)
            Task { @MainActor in
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
        case starting(Double)
        case idle
        case working
        case progress(Response)
        case done(Response)
        case failed(WrappedError)

        var response: Response? {
            if case .progress(let response) = self {
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
            let seed: Int

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
        status = .working
        Task {
            do {
                try await callAPI(request: request)
                // todo: ???
            } catch {
                print(error)
                status = .failed(Status.WrappedError(error))
            }
        }
    }

    func stop() {
        shouldStop = true
    }

    func callAPI(request config: Configuration) async throws {
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
//                var params = gpt_params(config)
                var tokens: [llama_token] = []
                var output = ""
                let start = Date()

                let embd_inp = Array<llama_token>(unsafeUninitializedCapacity: config.prompt.utf8.count) { buffer, initializedCount in
                    initializedCount = Int(llama_tokenize(self.ctx, config.prompt, buffer.baseAddress, Int32(buffer.count), true))
                }

                var embedding: [llama_token] = []

                while tokens.count < config.tokens {
                    if !embedding.isEmpty {
                        embedding.withUnsafeBufferPointer { ptr in
                            if llama_eval(self.ctx, ptr.baseAddress, Int32(ptr.count), Int32(tokens.count), Int32(config.threads)) != 0 {
                                continuation.resume(throwing: LLaMAError.evalFailed)
                            }
                        }
                    }
                }

//                let result = llama_predict(&params, &self.state) { progress in
//                    bridge_string(progress.token) { token, length in
//                        output.append(contentsOf: UnsafeBufferPointer<CChar>(start: token, count: Int(length)))
//                        print(length, output.suffix(Int(length)))
//                    }
//                    tokens += 1
//                    let params = progress.params.pointee
//                    Task { @MainActor [output, tokens] in
//                        self.status = .progress(.init(
//                            prompt: config.prompt,
//                            result: looseString(output),
//                            duration: Date().timeIntervalSince(start),
//                            finishReason: nil,
//                            tokens: tokens,
//                            seed: Int(params.seed)
//                        ))
//                    }
//                    return self.shouldStop
//                }
                self.shouldStop = false

//                func finish(reason: Status.Response.FinishReason) {
//                    Task { @MainActor [output, tokens, params] in
//                        try await Task.sleep(for: .milliseconds(30))
//                        self.status = .done(.init(
//                            prompt: config.prompt,
//                            result: looseString(output),
//                            duration: Date().timeIntervalSince(start),
//                            finishReason: reason,
//                            tokens: tokens,
//                            seed: Int(params.seed)
//                        ))
//                    }
//                    continuation.resume()
//                }

//                switch result {
//                case .error:
//                    continuation.resume(throwing: LLaMAError())
//                case .cancel:
//                    finish(reason: .cancelled)
//                case .limit:
//                    finish(reason: .limit)
//                case .end_of_text:
//                    finish(reason: .endOfText)
//                @unknown default:
//                    assertionFailure("Unexpected llama_predict result \(result.rawValue)")
//                    continuation.resume()
//                }
            }
        }
    }
}

class ClosureWrapper {
    typealias Handler = (Double) -> Void
    private let ptr = UnsafeMutablePointer<Handler>.allocate(capacity: 1)
    init(_ closure: @escaping Handler) {
        ptr.initialize(to: closure)
    }

    private var callback: @convention(c) (Double, UnsafeMutableRawPointer?) -> Void {
        { progress, ptr in
            let closurePointer = ptr?.assumingMemoryBound(to: Handler.self)
            closurePointer?.pointee(progress)
        }
    }

    var handler: llama_progress_handler {
        .init(handler: callback, ctx: ptr)
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
