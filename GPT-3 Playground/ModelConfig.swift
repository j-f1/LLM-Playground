//
//  ModelConfig.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import Foundation

struct Configuration {
    var prompt = ""

    var model = Model.davinci
    enum Model: String, CaseIterable {
        case davinci = "text-davinci-002"
        case curie = "text-curie-001"
        case babbage = "text-babbage-001"
    }

    var maxTokens = 256
    var temperature = 0.7
    var topP = 1.0
    var presencePenalty = 0.0
    var frequencyPenalty = 0.0
}
