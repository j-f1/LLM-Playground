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
                NavigationStack {
                    GeometryReader { geom in
                        ScrollView {
                            (Text(response.prompt).bold() + Text(response.result))
                                .frame(minHeight: geom.size.height - geom.safeAreaInsets.bottom - geom.safeAreaInsets.top)
                                .padding()
                        }.frame(width: geom.size.width)
                    }
                    .onDisappear {
                        completer.status = .idle
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button(action: { UIPasteboard.general.string = response.prompt + response.result }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        ToolbarItem(placement: .status) {
                            VStack {
                                let cost = Double(response.usage.totalTokens) * config.model.cost / 1000
                                Text("Cost: $\(cost, format: .number.precision(.fractionLength(2)))") + Text("\((cost - floor(cost)) * 1e5, format: .number.precision(.integerAndFractionLength(integer: 3, fraction: 0)))").foregroundColor(.secondary)
                                Text("Completion tokens: \(response.usage.totalTokens)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Button(action: {
                                config.prompt = response.prompt + response.result
                                showingResponse = false
                            }) {
                                Label("Insert", systemImage: "text.insert")
                            }
                        }
                    }
                }
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
