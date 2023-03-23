//
//  LLaMAConfig.swift
//  LLaMA Playground
//
//  Created by Jed Fox on 2023-03-11.
//

import Foundation
import Defaults

struct Configuration: Codable, Defaults.Serializable {
    var seed: Int32 = -1
    var prompt = "Write a tagline for an ice cream shop."
    var threads: Int32 = 4
    var tokens = 128
    var topK = 40
    var topP = 0.9
    var temperature = 0.8
    var batchSize = 8
    var model = Model.seven
    var repeatWindow = 64
    var repeatPenalty = 1.3

    enum Model: String, Codable, CaseIterable {
        case seven
        case thirteen
        case thirty
        case sixtyFive
    }
}
