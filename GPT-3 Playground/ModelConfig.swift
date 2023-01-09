//
//  ModelConfig.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI

extension String {
    static let insertToken = "[insert]"
}

struct Configuration: Encodable {
    var prompt = "Write a tagline for an ice cream shop."
    var instruction = ""
    
    var mode = Mode.complete
    enum Mode: CaseIterable {
        case complete
        case insert
        case edit
        
        var label: LocalizedStringKey {
            switch self {
            case .complete: return "Complete"
            case .insert: return "Insert"
            case .edit: return "Edit"
            }
        }
    }
    
    var model = Model.davinci
    enum Model: String, CaseIterable, Encodable {
        case davinci = "text-davinci-003"
        case curie = "text-curie-001"
        case babbage = "text-babbage-001"
        case ada = "text-ada-001"

        static let editModel = "text-davinci-edit-001"

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
    
    enum CodingKeys: String, CodingKey {
        case prompt, suffix
        case input, instruction
        
        case model
        
        case maxTokens
        
        case temperature, topP
        
        case presencePenalty, frequencyPenalty
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(topP, forKey: .topP)
        switch mode {
        case .complete:
            try container.encode(prompt, forKey: .prompt)
            
            try container.encode(model, forKey: .model)
            try container.encode(maxTokens, forKey: .maxTokens)
            try container.encode(presencePenalty, forKey: .presencePenalty)
            try container.encode(frequencyPenalty, forKey: .frequencyPenalty)
        case .insert:
            let splits = prompt.split(separator: String.insertToken, maxSplits: 1)
            try container.encode(String(splits[0]), forKey: .prompt)
            if splits.count == 2 {
                try container.encode(String(splits[1]), forKey: .suffix)
            }
            
            try container.encode(model, forKey: .model)
            try container.encode(maxTokens, forKey: .maxTokens)
            try container.encode(presencePenalty, forKey: .presencePenalty)
            try container.encode(frequencyPenalty, forKey: .frequencyPenalty)
        case .edit:
            try container.encode(Model.editModel, forKey: .model)
            try container.encode(prompt, forKey: .input)
            try container.encode(instruction, forKey: .instruction)
        }
    }
}
