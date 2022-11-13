//
//  ModelConfig.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import Foundation

struct Configuration: Encodable {
    var prompt = "Write a tagline for an ice cream shop."

    var model = Model.davinci
    enum Model: String, CaseIterable, Encodable {
        case davinci = "text-davinci-002"
        case curie = "text-curie-001"
        case babbage = "text-babbage-001"
        case ada = "text-ada-001"

        /// per 1k tokens
        var cost: Double {
            switch self {
            case .davinci: return 0.0200
            case .curie: return 0.0020
            case .babbage: return 0.0005
            case .ada: return 0.0004
            }
        }
    }

    var maxTokens = 256
    var temperature = 0.7 // 0...2
    var topP = 1.0
    var presencePenalty = 0.0
    var frequencyPenalty = 0.0
}
