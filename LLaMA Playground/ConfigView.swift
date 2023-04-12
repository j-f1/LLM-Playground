//
//  ConfigView.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI
import llama

private struct SliderField<Value, SliderValue: BinaryFloatingPoint, Format: ParseableFormatStyle>: View
where Format.FormatInput == Value, Format.FormatOutput == String, SliderValue.Stride: BinaryFloatingPoint {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var value: Value
    @Binding var sliderValue: SliderValue
    let format: Format
    let range: ClosedRange<SliderValue>

    var body: some View {
        Section {
            let slider = Slider(value: $sliderValue, in: range)
#if os(iOS)
            LabeledContent(title) {
                TextField(prompt, value: $value, format: format)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }
            slider
#else
            TextField(title, value: $value, format: format, prompt: Text(prompt))
                .multilineTextAlignment(.trailing)
            if #available(macOS 13, *) {
                LabeledContent {
                    EmptyView()
                } label: {
                    slider
                }
            } else {
                slider
            }
#endif
        }
    }
}

extension SliderField where Value == Double, SliderValue == Value, Format == FloatingPointFormatStyle<Double> {
    init(title: LocalizedStringKey, prompt: LocalizedStringKey, value: Binding<Value>, format: Format = .number.precision(.fractionLength(2)), range: ClosedRange<SliderValue>) {
        self.title = title
        self.prompt = prompt
        self._value = value
        self._sliderValue = value
        self.format = format
        self.range = range
    }
}

extension SliderField where Value: BinaryInteger, SliderValue == Double, Format == IntegerFormatStyle<Int> {
    init(title: LocalizedStringKey, prompt: LocalizedStringKey, value: Binding<Value>, format: Format = .number, range: ClosedRange<Value>) {
        self.title = title
        self.prompt = prompt
        self._value = value
        self._sliderValue = Binding { Double(value.wrappedValue) } set: { value.wrappedValue = Value($0) }
        self.format = format
        self.range = Double(range.lowerBound)...Double(range.upperBound)
    }
}

private struct IntField<Value: BinaryInteger, Format: ParseableFormatStyle>: View
where Format.FormatInput == Value, Format.FormatOutput == String {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var value: Value
    let format: Format
    let range: ClosedRange<Value>

    var body: some View {
#if os(iOS)
        LabeledContent(title) {
            TextField(prompt, value: $value, format: format)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
#else
        TextField(title, value: $value, format: format, prompt: Text(prompt))
            .multilineTextAlignment(.trailing)
#endif
    }
}


struct ConfigView: View {
    @Binding var config: Configuration
    @Binding var model: URL?
    let contextLength: Int32

    @Environment(\.dismiss) private var dismiss
    @State private var pickingModel = false

    var body: some View {
        Form {
            LabeledContent {
                Button(action: { pickingModel = true }) {
                    if let model {
                        HStack(spacing: 0) {
                            Image(systemName: "brain.head.profile").accessibilityHidden(true)
                            Text(" \(model.lastPathComponent)")
                        }
                    } else {
                        Text("Select…")
                    }
                }.fileImporter(isPresented: $pickingModel, allowedContentTypes: [.data]) { result in
                    if case .success(let url) = result {
                        model = url
                    }
                }
            } label: {
                Text("Model")
            }

            SliderField(
                title: "Maximum Tokens", prompt: "256",
                value: $config.tokens,
                sliderValue: Binding {
                    Darwin.sqrt(CGFloat(config.tokens))
                } set: {
                    config.tokens = Int(Darwin.pow($0, 2))
                },
                format: .number,
                range: 1...sqrt(CGFloat(contextLength))
            )

            Section {
                IntField(
                    title: "Seed", prompt: "-1 (random)",
                    value: $config.seed,
                    format: .number,
                    range: 0...100
                )
                Button("Randomize") {
                    config.seed = .random(in: 0 ..< .max)
                }
            }

            SliderField(
                title: "Temperature", prompt: "0.8",
                value: $config.temperature,
                range: 0...2
            )

//            Section {
//                IntField(
//                    title: "Top K", prompt: "40",
//                    value: $config.topK,
//                    format: .number,
//                    range: 0...100
//                )
//            }

            SliderField(
                title: "Top P", prompt: "0.9",
                value: $config.topP,
                range: 0...1
            )

            SliderField(
                title: "Repeat Penalty", prompt: "1.3",
                value: $config.repeatPenalty,
                sliderValue: Binding {
                    Darwin.sqrt(CGFloat(config.repeatPenalty))
                } set: {
                    config.repeatPenalty = Darwin.pow($0, 2)
                },
                format: .number,
                range: 1...sqrt(CGFloat(10))
            )

            SliderField(
                title: "Repeat Window", prompt: "64",
                value: $config.repeatWindow,
                range: 0...Int(contextLength)
            )

//            Section {
//                Picker("Model", selection: $config.model) {
//                    ForEach(Configuration.Model.allCases, id: \.self) { model in
//                        Text("\(model.rawValue)").tag(model)
//                    }
//                }
//            }
        }
        .monospacedDigit()
#if os(iOS)
        .keyboardType(.numberPad)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
#endif
        .navigationTitle("LLaMA Playground")
        .formStyle(.grouped)
    }
}

struct ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigView(config: .constant(Configuration()), model: .constant(nil), contextLength: 512)
    }
}
