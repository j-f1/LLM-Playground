//
//  LLaMAConfig.swift
//  LLaMA Playground
//
//  Created by Jed Fox on 2023-03-11.
//

import Foundation
import Defaults

struct Configuration: Codable, Defaults.Serializable {
    var prompt = "### Human: What is the meaning of life?\n### Assistant:"
    var threads: Int32 = 4
    var tokens = 2048
    var topK = 40
    var topP = 1.0
    var temperature = 0.19
    var batchSize = 32
    var repeatWindow = 64
    var repeatPenalty = 1.3
}
