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
    @Published var status = Status.idle

    private var state = llama_state()

    init() {
        DispatchQueue.global().async {
            _ = llama_bootstrap("/Users/jed/Documents/github-clones/llama.cpp/7b-q4_0.bin", &self.state)
        }
    }

    enum Status: Hashable {
        case idle
        case working
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

    func callAPI(request configuration: Configuration, openURL: OpenURLAction) async throws {
        // TODO!
//        llama_bootstrap()
    }
}
