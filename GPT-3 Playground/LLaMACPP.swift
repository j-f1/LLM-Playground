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
        case progress(String)
        case done(Response)
        case failed(WrappedError)

        struct Response: Hashable {
            let prompt: String
            let result: String
            let duration: Duration?
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
                try await callAPI(request: request, openURL: openURL)
            } catch {
                print(error)
                status = .failed(Status.WrappedError(error))
            }
        }
    }

    func callAPI(request config: Configuration, openURL: OpenURLAction) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var params = gpt_params(config)
                var result = ""
                let ok = llama_predict(&params, &self.state) { progress in
                    result += String(cString: llama_str(progress.token))
                    Task { @MainActor [result] in
                        self.status = .progress(result)
                    }
                }
                if ok {
                    Task { @MainActor [result] in
                        self.status = .done(.init(
                            prompt: config.prompt,
                            result: String(result.dropFirst(config.prompt.count)),
                            duration: nil
                        ))
                    }
                    continuation.resume()
                } else {
                    continuation.resume(throwing: LLaMAError())
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
        config.prompt.withCString { ptr in
            prompt = llama_str(ptr)
        }
    }
}

struct LLaMAError: Error {}
