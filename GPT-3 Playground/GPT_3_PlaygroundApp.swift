//
//  GPT_3_PlaygroundApp.swift
//  GPT-3 Playground
//
//  Created by Jed Fox on 2022-09-22.
//

import SwiftUI

func navigationStackIfNeeded<T: View>(@ViewBuilder content: () -> T) -> some View {
#if os(iOS)
    NavigationStack {
        content()
    }
#else
    content()
#endif
}

@main
struct GPT_3_PlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            navigationStackIfNeeded {
                ContentView()
            }
        }
        #if os(macOS)
        .windowToolbarStyle(.unifiedCompact)
        #endif
    }
}
