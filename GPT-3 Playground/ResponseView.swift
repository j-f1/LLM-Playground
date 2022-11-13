//
//  ResponseView.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-11-13.
//

import SwiftUI

struct ResponseView: View {
    let response: Completer.Status.Response
    @Binding var config: Configuration

    @Environment(\.dismiss) private var dismiss
    @AppStorage("Response Font") private var font = FontType.sans

    private enum FontType: String, Codable, CaseIterable {
        case sans = "Sans-Serif"
        case serif = "Serif"
        case mono = "Monospace"

        var font: Font {
            switch self {
            case .sans: return .body
            case .serif: return .system(.body, design: .serif)
            case .mono: return .system(.body, design: .monospaced)
            }
        }

        var icon: String {
            switch self {
            case .sans: return "character"
            case .serif: return "character.book.closed"
            case .mono: return "chevron.left.forwardslash.chevron.right"
            }
        }
    }

    var body: some View {
        GeometryReader { geom in
            ScrollView {
                (Text(response.prompt).bold() + Text(response.result))
                    .font(font.font)
                    .frame(minHeight: geom.size.height - geom.safeAreaInsets.bottom - geom.safeAreaInsets.top)
                    .padding()
            }.frame(width: geom.size.width)
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: { UIPasteboard.general.string = response.prompt + response.result }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            ToolbarItem(placement: .status) {
                VStack {
                    let cost = Double(response.usage.totalTokens) * config.model.cost / 1000
                    Text("Cost: $\(cost, format: .number.precision(.fractionLength(2)))") + Text("\((cost - floor(cost)) * 1e5, format: .number.precision(.integerAndFractionLength(integer: 3, fraction: 0)))").foregroundColor(.secondary)
                    Text("Completion tokens: \(response.usage.totalTokens)")
                        .foregroundColor(.secondary)
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Button(action: {
                        config.prompt = response.prompt + response.result
                        dismiss()
                    }) {
                        Label("Set as Prompt", systemImage: "text.insert")
                    }
                    Picker("Font", selection: $font) {
                        ForEach(FontType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
    }
}

//struct ResponseView_Previews: PreviewProvider {
//    static var previews: some View {
//        ResponseView()
//    }
//}
