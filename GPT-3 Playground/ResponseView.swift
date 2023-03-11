//
//  ResponseView.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-11-13.
//

import SwiftUI

struct ResponseView: View {
    let response: LLaMAInvoker.Status.Response
    @Binding var config: Configuration

    @Environment(\.dismiss) private var dismiss
    @AppStorage("Response Font") private var font = FontType.sans

    @Environment(\.displayScale) private var displayScale
    @StateObject private var annotation = ImageRenderer(content: AnnotationBadge())
    private struct AnnotationBadge: View {
        var body: some View {
            Label("Exceeded Token Limit", systemImage: "exclamationmark.triangle")
                .bold()
                .symbolVariant(.fill)
                .foregroundColor(.white)
                .font(.caption2)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(.yellow, in: RoundedRectangle(cornerRadius: 3))
        }
    }

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
        let combinedText = config.prompt + response.result

        let copyButton = Button(action: {
            #if os(iOS)
            UIPasteboard.general.string = combinedText
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(combinedText, forType: .string)
            #endif
        }) {
            Label("Copy", systemImage: "doc.on.doc")
        }

        let promptButton = Button(action: {
            config.prompt = combinedText
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
            Text("Completion tokens: \(config.tokens)")
                .foregroundColor(.secondary)
                #if os(iOS)
                .font(.caption)
                #endif
            if let duration = response.duration {
                Text("Duration: \(duration, format: .duration)")
                    .foregroundStyle(.tertiary)
                    #if os(iOS)
                    .font(.caption)
                    #endif
            }
            #if os(macOS)
            Label("\(config.temperature, format: .number.precision(.fractionLength(2)))", systemImage: {
                if config.temperature < 0.5 {
                    return "thermometer.snowflake"
                }
                if config.temperature < 1 {
                    return "thermometer.low"
                }
                if config.temperature < 1.5 {
                    return "thermometer.medium"
                }
                return "thermometer.high"
            }())
            #endif
        }

        let resultText = (Text(config.prompt).bold() + Text(response.result)).font(font.font)

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
        .onAppear { annotation.scale = displayScale }
        .onChange(of: displayScale, perform: { annotation.scale = $0 })
        #else
        HStack(spacing: 0) {
            ScrollView {
                HStack {
                    resultText
                        .frame(minWidth: 300, idealWidth: 400)
                        .padding()
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                }
            }
            .frame(minHeight: 300)
            .layoutPriority(1)
            Divider()
            VStack {
                costLabel
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Font").font(.headline)
                    fontPicker
                        .pickerStyle(.radioGroup)
                        .labelStyle(.titleOnly)
                        .labelsHidden()
                }
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
            .fixedSize(horizontal: true, vertical: false)
            .padding()
            .background(.regularMaterial)
        }
        .frame(minWidth: 676)
        .onAppear { annotation.scale = displayScale }
        .onChange(of: displayScale, perform: { annotation.scale = $0 })
        #endif
    }
}

//struct ResponseView_Previews: PreviewProvider {
//    static var previews: some View {
//        ResponseView()
//    }
//}
