//
//  LLaMAConfig.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2023-03-11.
//

import Foundation
import Defaults

struct Configuration: Codable, Defaults.Serializable {
    var seed = -1
    var prompt = "Write a tagline for an ice cream shop."
    var threads = 4
    var tokens = 128
    var topK = 40
    var topP = 0.9
    var temperature = 0.8
    var batchSize = 8
    var model = Model.seven

    enum Model: String, Codable, CaseIterable {
        case seven
        case thirty
    }
}
