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
        let copyButton = Button(action: {
            let value = response.prompt + response.result
            #if os(iOS)
            UIPasteboard.general.string = value
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            #endif
        }) {
            Label("Copy", systemImage: "doc.on.doc")
        }

        let promptButton = Button(action: {
            config.prompt = response.prompt + response.result
            dismiss()
        }) {
            Label("Set as Prompt", systemImage: "text.insert")
        }

        let fontPicker = Picker("Font", selection: $font) {
            ForEach(FontType.allCases, id: \.self) { type in
                Label(type.rawValue, systemImage: type.icon).tag(type)
            }
        }

        let costLabel = Group {
            let cost = Double(response.usage.totalTokens) * config.model.cost / 1000
            Text("Cost: $\(cost, format: .number.precision(.fractionLength(2)))") + Text("\((cost - floor(cost)) * 1e5, format: .number.precision(.integerAndFractionLength(integer: 3, fraction: 0)))").foregroundColor(.secondary)
            Text("Completion tokens: \(response.usage.totalTokens)")
                .foregroundColor(.secondary)
        }

        let resultText = (
            (Text(response.prompt).bold() + Text(response.result))
                .font(font.font)
        )

#if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
#endif

        #if os(iOS)
        GeometryReader { geom in
            ScrollView {
                resultText
                    .frame(minHeight: geom.size.height - geom.safeAreaInsets.bottom - geom.safeAreaInsets.top)
                    .padding()
            }.frame(width: geom.size.width)
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                copyButton
            }
            ToolbarItem(placement: .status) {
                VStack {
                    costLabel
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    promptButton
                    fontPicker
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        #else
        HStack {
            ScrollView {
                resultText.padding()
            }
            VStack {
                costLabel
                Spacer()
                fontPicker
                    .pickerStyle(.radioGroup)
                    .labelStyle(.titleOnly)
                Spacer()
                copyButton
                Spacer()
                HStack {
                    promptButton
                    Button("Dismiss") {
                        dismiss()
                    }.keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .background(.regularMaterial)
        }
        #endif
    }
}

//struct ResponseView_Previews: PreviewProvider {
//    static var previews: some View {
//        ResponseView()
//    }
//}
