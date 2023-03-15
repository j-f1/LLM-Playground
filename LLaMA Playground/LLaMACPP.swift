//
//  LLaMACPP.swift
//  LLaMA Playground
//
//  Created by Jed Fox on 2023-03-11.
//

import Foundation
import SwiftUI
import LLaMAcpp

class LLaMAInvoker: ObservableObject {
    @Published var status = Status.working

    private var state = llama_state()
    private var shouldStop = false

    var hParams: llama_hparams {
        state.model.hparams
    }

    static let shared = LLaMAInvoker()

    private init() {
        DispatchQueue.global().async {
//            _ = llama_bootstrap(Bundle.main.path(forResource: "7b-q4_0", ofType: "bin"), &self.state) { progress in
            _ = llama_bootstrap("/Users/jed/Documents/github-clones/llama.cpp/7b-q4_0.bin", &self.state) { progress in
                Task { @MainActor in
                    self.status = .starting(progress)
                }
            }
            Task { @MainActor in
                self.status = .idle
            }
        }
    }
    deinit {
        llama_finalize(&state)
    }

    enum Status: Hashable {
        case starting(Float)
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
                var params = gpt_params(config)
                var output: [CChar] = []
                var tokens = 0
                let start = Date()
                let result = llama_predict(&params, &self.state) { progress in
                    bridge_string(progress.token) { token, length in
                        output.append(contentsOf: UnsafeBufferPointer<CChar>(start: token, count: Int(length)))
//                        print(length, output.suffix(50))
                    }
                    tokens += 1
                    let params = progress.params.pointee
                    Task { @MainActor [output, tokens] in
                        self.status = .progress(.init(
                            prompt: config.prompt,
                            result: looseString(output),
                            duration: Date().timeIntervalSince(start),
                            finishReason: nil,
                            tokens: tokens,
                            seed: Int(params.seed)
                        ))
                    }
                    return self.shouldStop
                }
                self.shouldStop = false

                func finish(reason: Status.Response.FinishReason) {
                    Task { @MainActor [output, tokens, params] in
                        try await Task.sleep(for: .milliseconds(30))
                        self.status = .done(.init(
                            prompt: config.prompt,
                            result: looseString(output),
                            duration: Date().timeIntervalSince(start),
                            finishReason: reason,
                            tokens: tokens,
                            seed: Int(params.seed)
                        ))
                    }
                    continuation.resume()
                }

                switch result {
                case .error:
                    continuation.resume(throwing: LLaMAError())
                case .cancel:
                    finish(reason: .cancelled)
                case .limit:
                    finish(reason: .limit)
                case .end_of_text:
                    finish(reason: .endOfText)
                @unknown default:
                    assertionFailure("Unexpected llama_predict result \(result.rawValue)")
                    continuation.resume()
                }
            }
        }
    }
}

extension gpt_params {
    init(_ config: Configuration) {
        self.init()
//        n_threads = Int32(config.threads)
        n_predict = Int32(config.tokens)
        top_k = Int32(config.topK)
        top_p = Float(config.topP)
        temp = Float(config.temperature)
        n_batch = Int32(config.batchSize)
        prompt = bridge_string(config.prompt)
        seed = config.seed
        repeat_last_n = Int32(config.repeatWindow)
        repeat_penalty = Float(config.repeatPenalty)
//        n_threads = 8
    }
}

func looseString(_ bytes: [CChar]) -> String {
    return String(cString: bytes + [0])
}

struct LLaMAError: Error {}
