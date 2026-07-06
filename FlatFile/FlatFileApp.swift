//
//  FlatFileApp.swift
//  FlatFile
//
//  Created by Kate Ayelet Benediktsson on 4/6/26.
//

import SwiftUI

@main
struct FlatFileApp: App {
    @State private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { await store.start() }
        }
    }
}
