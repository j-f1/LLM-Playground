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
    @StateObject var completer = Completer()
    @Environment(\.openURL) var openURL

    func complete() {
        completer.complete(config, openURL: openURL)
    }

    @ViewBuilder
    var completeButton: some View {
        switch completer.status {
        case .idle:
            Button(action: complete) {
                Label("Complete", systemImage: "play.fill")
            }
        case .fetching:
            ProgressView()
        case .done(let response):
            Button(action: complete) {
                Label("Complete", systemImage: "play.fill")
            }.sheet(isPresented: $showingResponse) {
                (Text(response.prompt).bold() + Text(response.result))			
                    .onDisappear {
                        completer.status = .idle
                    }
                let _ = print(response.usage)
            }.onAppear {
                showingResponse = true
            }
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
#else
        HSplitView {
            TextEditor(text: $config.prompt)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        completeButton
                    }
                }
                .frame(minWidth: 300)
            ScrollView {
                ConfigView(config: $config)
                    .frame(minWidth: 300)
            }
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
