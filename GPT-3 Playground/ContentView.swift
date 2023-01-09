//
//  ContentView.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI

struct ContentView: View {
    @State var showingConfig = false
    @State var showingResponse = false
    @State var config = Configuration()
    @StateObject var completer = OpenAIAPI()
    @Environment(\.openURL) var openURL
    @AppStorage("prompt") var savedPrompt = "Write a tagline for an ice cream shop."

    func run() {
        savedPrompt = config.prompt
        completer.perform(config, openURL: openURL)
    }

    @ViewBuilder
    var completeButton: some View {
        switch completer.status {
        case .idle:
            Button(action: run) {
                Label("Run", systemImage: "play.fill")
            }.keyboardShortcut("R")
        case .fetching:
            ProgressView().controlSize(.small)
        case .done(let response):
            Button(action: run) {
                Label("Run", systemImage: "play.fill")
            }.sheet(isPresented: $showingResponse) {
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
            }.onAppear {
                showingResponse = true
            }.keyboardShortcut("R")
        }
    }
    var body: some View {
#if os(iOS)
        TextEditor(text: $config.prompt)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { showingConfig = true }) {
                        Label("Configuration", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    completeButton
                }
            }
            .sheet(isPresented: $showingConfig) {
                NavigationStack {
                    ConfigView(config: $config)
                }
            }
            .onAppear {
                config = Configuration(prompt: savedPrompt)
            }
#else
        HStack(spacing: 0) {
            TextEditor(text: $config.prompt)
                .frame(minWidth: 300)
                .padding()
                .background(Color(nsColor: .textBackgroundColor))
            Divider()
            ScrollView {
                VStack {
                    ConfigView(config: $config)
                    Spacer()
                }
            }
            .frame(width: 300)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                completeButton
            }
        }
        .onAppear {
            config = Configuration(prompt: savedPrompt)
        }
#endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        navigationStackIfNeeded {
            ContentView()
        }
    }
}
