//
//  Completer.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI

@MainActor
class Completer: ObservableObject {
    @Published var status = Status.idle

    enum Status: Equatable {
        case idle
        case fetching
        case done(Response)

        struct Response: Equatable {
            let prompt: String
            let result: String
            let usage: Usage
        }
    }

    func complete(_ configuration: Configuration, openURL: OpenURLAction) {
        assert(status != .fetching)
        status = .fetching
        Task {
            do {
                try await callAPI(configuration: configuration, openURL: openURL)
            } catch {
                print(error)
                status = .idle
            }
        }
    }

    private let endpoint = URL(string: "https://api.openai.com/v1/completions")!
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
    func callAPI(configuration: Configuration, openURL: OpenURLAction) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(configuration)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(UserDefaults.standard.string(forKey: "API Key") ?? "")", forHTTPHeaderField: "Authorization")
        let data = try await URLSession.shared.data(for: request).0
        do {
            let rawResponse = try decoder.decode(Response.self, from: data)
            let response = Status.Response(prompt: configuration.prompt, result: rawResponse.choices[0].text, usage: rawResponse.usage)
            self.status = .done(response)

            var shortcutsURL = URL(string: "shortcuts://x-callback-url/run-shortcut")!
            let markdownText = "**\(configuration.prompt.split(separator: "\n").joined(separator: "**\n**"))**\(response.result)"
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
            openURL(shortcutsURL)
        } catch {
            print(String(data: data, encoding: .utf8) ?? "<no data>")
            throw error
        }
    }
}

struct Usage: Decodable, Equatable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

private struct Response: Decodable {
    let choices: [Choice]
    let usage: Usage
    struct Choice: Decodable {
        let text: String
        let finishReason: String
    }
}
