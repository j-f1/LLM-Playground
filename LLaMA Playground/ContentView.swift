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
    @StateObject var completer = LLaMAInvoker()
    @Environment(\.openURL) var openURL
    
    @FocusState var focusedEditField: EditField?
    @State var selectedTab = EditField.input
    enum EditField {
        case input, instruction
    }

    @State private var modal: Sheet?
    private enum Sheet: Identifiable, Hashable {
        case response(LLaMAInvoker.Status.Response)
        case progress(LLaMAInvoker.Status.Response)
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
        case .working:
            ProgressView()
                #if os(macOS)
                .controlSize(.small)
                .padding(.trailing, 3)
                #endif
        default:
            Button(action: run) { Label("Run", systemImage: "play.fill") }
                .keyboardShortcut("R")
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
                    if focusedEditField != nil {
                        focusedEditField = $0
                    }
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
            VStack {
                TextEditor(text: $config.prompt)
                    .padding(8)
                    .frame(minWidth: 300)
                    .background(Color(nsColor: .textBackgroundColor))
            }
            Divider()
            ScrollView {
                VStack {
                    ConfigView(config: $config, hParams: completer.hParams)
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
                case .idle, .working:
                    modal = nil
                case .progress(let response):
                    modal = .progress(response)
                case .done(let response):
                    modal = .response(response)
                case .failed(let error):
                    modal = .error(error)
                }
            }
            .sheet(item: $modal) {
                switch $0 {
                case .response(let response), .progress(let response):
                    if #available(macOS 13.0, *) {
                        NavigationStack {
                            ResponseView(
                                response: response,
                                isDone: completer.status.isDone,
                                config: $config,
                                onStop: completer.stop
                            )
                                .onDisappear {
                                    completer.status = .idle
                                }
                        }
                    } else {
                        ResponseView(
                            response: response,
                            isDone: completer.status.isDone,
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
