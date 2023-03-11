//
//  DurationFormatStyle.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2023-01-15.
//

import Foundation

struct DurationFormatStyle: FormatStyle {
    func format(_ value: Duration) -> String {
        value.description
    }
}

extension FormatStyle where Self == DurationFormatStyle {
    static var duration: Self { Self() }
}
