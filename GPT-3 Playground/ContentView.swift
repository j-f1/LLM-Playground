//
//  ContentView.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI

struct ContentView: View {
    @State var text = "Write a tagline for an ice cream shop."
    @State var showingConfig = false
    @State var config = Configuration()
    var body: some View {
#if os(iOS)
        TextEditor(text: $text)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { showingConfig = true }) {
                        Label("Configuration", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { }) {
                        Label("Complete", systemImage: "play.fill")
                    }
                }
            }
            .sheet(isPresented: $showingConfig) {
                ConfigView(config: $config)
            }
#else
        HSplitView {
            TextEditor(text: $text)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { }) {
                            Label("Complete", systemImage: "play.fill")
                        }
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
