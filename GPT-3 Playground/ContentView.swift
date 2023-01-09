//
//  ContentView.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI
import Defaults

extension Defaults.Keys {
    static let config = Defaults.Key("Configuration", default: Configuration())
}

struct ContentView: View {
    @Default(.config) var config
    @StateObject var completer = OpenAIAPI()
    @Environment(\.openURL) var openURL
    
    @FocusState var focusedEditField: EditField?
    @State var selectedTab = EditField.input
    enum EditField {
        case input, instruction
    }

    @State private var modal: Sheet?
    private enum Sheet: Identifiable, Hashable {
        case response(OpenAIAPI.Status.Response)
        case error(OpenAIAPI.Status.WrappedError)
        #if os(iOS)
        case config
        #endif

        var id: Self { self }
    }

    func run() {
        completer.perform(config, openURL: openURL)
    }

    @ViewBuilder
    var completeButton: some View {
        switch completer.status {
        case .fetching:
            ProgressView()
                #if os(macOS)
                .controlSize(.small)
                .padding(.trailing, 3)
                #endif
        default:
            Button(action: run) { Label("Run", systemImage: "play.fill") }
                .keyboardShortcut("R")
                .disabled(config.mode == .insert && !config.prompt.contains(String.insertToken))
        }
    }
    var body: some View {
#if os(iOS)
        let content = Group {
            switch config.mode {
            case .complete, .insert:
                TextEditor(text: $config.prompt)
            case .edit:
                TabView(selection: $selectedTab) {
                    TextEditor(text: $config.prompt)
                        .focused($focusedEditField, equals: .input)
                        .safeAreaInset(edge: .bottom) {
                            Text("Input").font(.headline)
                                .padding(.bottom, -2)
                        }
                        .tag(EditField.input)
                    TextEditor(text: $config.instruction)
                        .focused($focusedEditField, equals: .instruction)
                        .safeAreaInset(edge: .bottom) {
                            Text("Instruction").font(.headline)
                                .padding(.bottom, -2)
                        }
                        .tag(EditField.instruction)
                }
                .onChange(of: selectedTab) {
                    focusedEditField = $0
                }
                .symbolVariant(.circle.fill)
                .tabViewStyle(.page)
                .padding(.bottom, 5)
                .onAppear {
                    UIPageControl.appearance().currentPageIndicatorTintColor = .label
                    UIPageControl.appearance().pageIndicatorTintColor = .tertiaryLabel

                }
            }
        }.toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { modal = .config }) {
                    Label("Configuration", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                completeButton
            }
        }
#else
        let content = HStack(spacing: 0) {
            Group {
                switch config.mode {
                case .complete, .insert:
                    TextEditor(text: $config.prompt)
                        .padding(8)
                case .edit:
                    VSplitView {
                        VStack(alignment: .leading) {
                            TextEditorLabel(title: "Input")
                            TextEditor(text: $config.prompt)
                        }.padding(8)
                        VStack(alignment: .leading) {
                            TextEditorLabel(title: "Instruction")
                            TextEditor(text: $config.instruction)
                        }.padding(8)
                    }
                }
            }
            .frame(minWidth: 300)
            .background(Color(nsColor: .textBackgroundColor))
            Divider()
            ScrollView {
                VStack {
                    ConfigView(config: $config)
                    Spacer()
                }
            }
            .frame(width: 300)
        }.toolbar {
            ToolbarItem(placement: .primaryAction) {
                completeButton
            }
        }
#endif
        content
            .onChange(of: completer.status) { status in
                switch status {
                case .idle, .fetching:
                    modal = nil
                case .done(let response):
                    modal = .response(response)
                case .failed(let error):
                    modal = .error(error)
                }
            }
            .sheet(item: $modal) {
                switch $0 {
                case .response(let response):
                    if #available(macOS 13.0, *) {
                        NavigationStack {
                            ResponseView(response: response, config: $config)
                                .onDisappear {
                                    completer.status = .idle
                                }
                        }
                    } else {
                        ResponseView(response: response, config: $config)
                            .onDisappear {
                                completer.status = .idle
                            }
                    }
                case .error(let error):
                    NavigationStack {
                        VStack {
                            Text(error.error.localizedDescription)
                            if let error = error.error as? OpenAIError {
                                Text("Error Code: ") + Text(error.type).font(.body.monospaced())
                            }
                        }
                        .navigationTitle("Failed to Run")
                    }.toolbar {
                        Button("Done", role: .cancel) { modal = nil }
                            .keyboardShortcut(.defaultAction)
                    }
                #if os(iOS)
                case .config:
                    NavigationStack {
                        ConfigView(config: $config)
                    }
                #endif
                }
            }
    }
}

struct TextEditorLabel: View {
    let title: LocalizedStringKey
    
    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.leading, 4)
            .foregroundColor(.secondary)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        navigationStackIfNeeded {
            ContentView()
        }
    }
}
