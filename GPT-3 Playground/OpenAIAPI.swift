//
//  OpenAIAPI.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI

@MainActor
class OpenAIAPI: ObservableObject {
    @Published var status = Status.idle

    enum Status: Hashable {
        case idle
        case fetching
        case done(Response)
        case failed(WrappedError)

        struct Response: Hashable {
            let prompt: Prompt
            enum Prompt: Hashable {
                case complete(String)
                case insert(before: String, after: String)
                case edit(input: String, instruction: String)
                
                
                init(_ config: Configuration) {
                    switch config.mode {
                    case .complete:
                        self = .complete(config.prompt)
                    case .insert:
                        if config.prompt.hasPrefix(String.insertToken) {
                            self = .insert(before: "", after: String(config.prompt.dropFirst(String.insertToken.count)))
                        } else if config.prompt.hasSuffix(String.insertToken) {
                            self = .insert(before: String(config.prompt.dropLast(String.insertToken.count)), after: "")
                        } else {
                            let splits = config.prompt.split(separator: String.insertToken, maxSplits: 1)
                            self = .insert(before: String(splits[0]), after: String(splits[1]))
                        }
                    case .edit:
                        self = .edit(input: config.prompt, instruction: config.instruction)
                    }
                }
            }
            let result: String
            let finishReason: String?
            let usage: Usage
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

    func perform(_ request: Configuration, openURL: OpenURLAction) {
        if case .fetching = status {
            assertionFailure()
        }
        status = .fetching
        Task {
            do {
                try await callAPI(request: request, openURL: openURL)
            } catch {
                print(error)
                status = .failed(Status.WrappedError(error))
            }
        }
    }

    private let baseEndpoint = URL(string: "https://api.openai.com/v1")!
    private func endpoint(for configuration: Configuration) -> URL {
        switch configuration.mode {
        case .complete, .insert:
            return baseEndpoint.appending(component: "completions")
        case .edit:
            return baseEndpoint.appending(component: "edits")
        }
    }
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let encoder = JSONDecoder()
        encoder.keyDecodingStrategy = .convertFromSnakeCase
        return encoder
    }()
    
    private func bold(_ s: String) -> String {
        "**\(s.split(separator: "\n").joined(separator: "**\n**"))**"
    }
    func callAPI(request configuration: Configuration, openURL: OpenURLAction) async throws {
        var request = URLRequest(url: endpoint(for: configuration))
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(configuration.forAPI)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(UserDefaults.standard.string(forKey: "API Key") ?? "")", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        do {
            let rawResponse = try decoder.decode(Response.self, from: data)
            let response = Status.Response(
                prompt: .init(configuration),
                result: rawResponse.choices[0].text,
                finishReason: rawResponse.choices[0].finishReason,
                usage: rawResponse.usage,
                duration: response.value(forHTTPHeaderField: "openai-processing-ms")
                    .flatMap { Int($0) }
                    .map(Duration.milliseconds)
            )
            self.status = .done(response)

            var shortcutsURL = URL(string: "shortcuts://x-callback-url/run-shortcut")!
            let markdownText: String
            switch response.prompt {
            case let .complete(prompt):
                markdownText = bold(prompt) + response.result
            case let .insert(before, after):
                markdownText = bold(before) + response.result + bold(after)
            case let .edit(input, instructions):
                markdownText = "Input: \(input)\n\nPrompt: \(instructions)\n\n\(response.result)"
            }
            let items: [URLQueryItem] = [
                .init(name: "name", value: "GPT-3 Logbook"),
                .init(name: "input", value: "text"),
                .init(name: "text", value: markdownText),
                .init(name: "x-success", value: "gpt-3://")
            ]
            if #available(macOS 13.0, *) {
                shortcutsURL.append(queryItems: items)
            } else {
                var components = URLComponents(url: shortcutsURL, resolvingAgainstBaseURL: true)!
                components.queryItems = items
                shortcutsURL = components.url!
            }
            #if os(macOS)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            try await NSWorkspace.shared.open(shortcutsURL, configuration: config)
            #else
            openURL(shortcutsURL)
            #endif
        } catch {
            for (header, value) in response.allHeaderFields {
                print("\(header as! String): \(value)")
            }
            print(String(data: data, encoding: .utf8) ?? "<no data>")
            if let response = try? decoder.decode(ErrorResponse.self, from: data) {
                throw response.error
            }
            throw error
        }
    }
}

struct Usage: Decodable, Hashable {
    let promptTokens: Int
    let completionTokens: Int?
    let totalTokens: Int
}

private struct Response: Decodable {
    let choices: [Choice]
    let usage: Usage
    struct Choice: Decodable {
        let text: String
        let finishReason: String?
    }
}

private struct ErrorResponse: Decodable {
    let error: OpenAIError
}

struct OpenAIError: Error, Decodable, LocalizedError {
    let message: String
    let type: String
    // also present: `param`, `code` of unknown type
    
    enum CodingKeys: String, CodingKey {
        case message
        case type
    }
    
    init(from decoder: Decoder) throws {
        let dict = try decoder.container(keyedBy: CodingKeys.self)
        message = try dict.decode(String.self, forKey: .message)
        type = try dict.decode(String.self, forKey: .type)
    }
    
    var errorDescription: String? {
        message
    }
}
