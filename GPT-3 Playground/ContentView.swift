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
        let button = Button(action: run) { Label("Run", systemImage: "play.fill") }
            .keyboardShortcut("R")
            .disabled(config.mode == .insert && !config.prompt.contains(String.insertToken))
        switch completer.status {
        case .idle:
            button
        case .fetching:
            ProgressView().controlSize(.small)
        case .done(let response):
            button.sheet(isPresented: $showingResponse) {
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
            }
        case .failed(let error):
            button.alert(isPresented: $showingResponse) {
                Alert(
                    title: (error as? OpenAIError).map { Text("Failed to run: \($0.type)") } ?? Text("Failed to run"),
                    message: Text(error.localizedDescription),
                    dismissButton: .cancel(Text("Dismiss"))
                )
            }.onAppear {
                showingResponse = true
            }
        }
    }
    var body: some View {
#if os(iOS)
        let content = Group {
            switch config.mode {
            case .complete, .insert:
                TextEditor(text: $config.prompt)
            case .edit:
                TabView {
                    TextEditor(text: $config.prompt)
                        .safeAreaInset(edge: .bottom) {
                            Text("Input").font(.headline)
                                .padding(.bottom, -2)
                        }
                    TextEditor(text: $config.instruction)
                        .safeAreaInset(edge: .bottom) {
                            Text("Instruction").font(.headline)
                                .padding(.bottom, -2)
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
                Button(action: { showingConfig = true }) {
                    Label("Configuration", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                completeButton
            }
        }.sheet(isPresented: $showingConfig) {
            NavigationStack {
                ConfigView(config: $config)
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
            .onAppear {
                config = Configuration(prompt: savedPrompt)
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
