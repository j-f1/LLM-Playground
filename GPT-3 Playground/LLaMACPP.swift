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

    init() {
        DispatchQueue.global().async {
            _ = llama_bootstrap("/Users/jed/Documents/github-clones/llama.cpp/7b-q4_0.bin", &self.state)
            Task { @MainActor in
                self.status = .idle
            }
        }
    }

    enum Status: Hashable {
        case idle
        case working
        case progress(Response)
        case done(Response)
        case failed(WrappedError)

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
            let duration: Duration?
            let finishReason: FinishReason?

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
                var output = ""
                let result = llama_predict(&params, &self.state) { progress in
                    output += String(progress.token)
                    Task { @MainActor [output] in
                        self.status = .progress(.init(
                            prompt: config.prompt,
                            result: output,
                            duration: nil,
                            finishReason: nil
                        ))
                    }
                    return self.shouldStop
                }
                self.shouldStop = false

                func finish(reason: Status.Response.FinishReason) {
                    Task { @MainActor [output] in
                        self.status = .done(.init(
                            prompt: config.prompt,
                            result: output,
                            duration: nil,
                            finishReason: reason
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
        n_threads = Int32(config.threads)
        n_predict = Int32(config.tokens)
        top_k = Int32(config.topK)
        top_p = Float(config.topP)
        temp = Float(config.temperature)
        n_batch = Int32(config.batchSize)
        prompt = std.string(config.prompt)
    }
}

struct LLaMAError: Error {}
