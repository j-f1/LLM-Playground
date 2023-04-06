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
    static let model = Defaults.Key<URL?>("Model URL")
}

struct ContentView: View {
    @Default(.config) var config
    @ObservedObject var completer = LLaMAInvoker.shared
    @Environment(\.openURL) var openURL
    @Default(.model) var model
    
    @FocusState var focusedEditField: EditField?
    @State var selectedTab = EditField.input
    enum EditField {
        case input, instruction
    }

    @State private var modal: Sheet?
    private enum Sheet: Identifiable, Hashable {
        case response
        case progress
        case error(LLaMAInvoker.Status.WrappedError)
        #if os(iOS)
        case config
        #endif

        var id: Self { self }
    }

    func run() {
        completer.complete(config, openURL: openURL)
    }

    @ViewBuilder
    var completeButton: some View {
        switch completer.status {
        case .starting, .working:
            ProgressView()
                #if os(macOS)
                .controlSize(.small)
                .padding(.trailing, 3)
                #endif
        default:
            Button(action: run) { Label("Run", systemImage: "play.fill") }
                .keyboardShortcut("R")
                .disabled(completer.status == .missingModel)
        }
    }
    var body: some View {
#if os(iOS)
        let content = TextEditor(text: $config.prompt)
            .toolbar {
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
            VStack {
                TextEditor(text: $config.prompt)
                    .padding(8)
                    .frame(minWidth: 300)
                    .background(Color(nsColor: .textBackgroundColor))
            }
            Divider()
            ScrollView {
                VStack {
                    ConfigView(config: $config, model: $model, contextLength: completer.contextLength)
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
            .onAppear {
                if let model {
                    completer.loadModel(at: model)
                }
            }
            .onChange(of: model) { model in
                if let model {
                    completer.loadModel(at: model)
                }
            }
            .onChange(of: completer.status) { status in
                switch status {
                case .missingModel, .idle, .working, .starting:
                    modal = nil
                case .progress, .done:
                    modal = .response
                case .failed(let error):
                    modal = .error(error)
                }
            }
            .sheet(item: $modal) {
                switch $0 {
                case .response, .progress:
                    if #available(macOS 13.0, *) {
                        NavigationStack {
                            ResponseView(
                                response: completer.status.response!,
                                config: $config,
                                onStop: completer.stop
                            )
                                .onDisappear {
                                    completer.status = .idle
                                }
                        }
                    } else {
                        ResponseView(
                            response: completer.status.response!,
                            config: $config,
                            onStop: completer.stop
                        )
                            .onDisappear {
                                completer.status = .idle
                            }
                    }
                case .error(let error):
                    NavigationStack {
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(error.error.localizedDescription)
                            }
                            .padding()
                        }
                        .navigationTitle("Failed to Run")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done", role: .cancel) { modal = nil }
                                    .keyboardShortcut(.defaultAction)
                            }
                        }
                    }
                    #if os(iOS)
                    .presentationDetents([.medium])
                    #else
                    .frame(width: 400, height: 200)
                    .textSelection(.enabled)
                    #endif
                #if os(iOS)
                case .config:
                    NavigationStack {
                        ConfigView(config: $config, model: $model, contextLength: completer.contextLength)
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
