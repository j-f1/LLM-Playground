//
//  ConfigView.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI

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

struct ConfigView: View {
    @Binding var config: Configuration
    @Environment(\.dismiss) var dismiss
    @AppStorage("API Key") var apiKey = ""

    var body: some View {
        Form {
            Section {} header: {
                Picker("Mode", selection: $config.mode) {
                    ForEach(Configuration.Mode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .textCase(nil)
                .padding(.horizontal, -16)
            }

            if config.mode != .edit {
                SliderField(
                    title: "Maximum Tokens", prompt: "256",
                    value: $config.maxTokens,
                    sliderValue: Binding {
                        sqrt(Double(config.maxTokens))
                    } set: {
                        config.maxTokens = Int(pow($0, 2))
                    },
                    format: .number,
                    range: 0...sqrt(config.model == .davinci ? 4096 : 2048)
                )
            }

            SliderField(
                title: "Temperature", prompt: "0.7",
                value: $config.temperature,
                range: 0...2
            )

            SliderField(
                title: "Top P", prompt: "1",
                value: $config.topP,
                range: 0...1
            )

            if config.mode != .edit {
                SliderField(
                    title: "Presence Penalty", prompt: "0",
                    value: $config.presencePenalty,
                    range: -2...2
                )
                
                SliderField(
                    title: "Frequency Penalty", prompt: "0",
                    value: $config.frequencyPenalty,
                    range: -2...2
                )
                
                Section {
                    Picker("Model", selection: $config.model) {
                        ForEach(Configuration.Model.allCases, id: \.self) { model in
                            Text("\(model.rawValue)").tag(model)
                        }
                    }
                }
            }

            #if os(iOS)
            Section("API Key") {
                SecureField("abcd1234", text: $apiKey)
                    .keyboardType(.asciiCapable)
            }
            #else
            SecureField("API Key", text: $apiKey, prompt: Text("abcd1234"))
            #endif
        }
        .animation(.default, value: config.mode)
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
        .navigationTitle("Configuration")
        .formStyle(.grouped)
    }
}

struct ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigView(config: .constant(Configuration()))
    }
}
