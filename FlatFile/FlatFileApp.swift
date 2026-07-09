//
//  FlatFileApp.swift
//  FlatFile
//
//  Created by Kate Ayelet Benediktsson on 4/6/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct FlatFileApp: App {
    @State private var store = StoreManager()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { await store.start() }
        }
    }
}

/// Hands files the OS asks us to open (Finder "Open With", Spotlight, a Files
/// tap, drag onto the Dock icon) to whichever view is showing the table.
/// A one-slot mailbox: the view observes `pendingURL` and consumes it.
@MainActor
@Observable
final class OpenFileBroker {
    static let shared = OpenFileBroker()
    private(set) var pendingURL: URL?

    func deliver(_ urls: [URL]) {
        // One table per window for now — open the first file we were handed.
        guard let url = urls.first(where: { $0.isFileURL }) else { return }
        pendingURL = url
    }

    func consume() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
    }
}

#if os(macOS)
/// On macOS, documents opened from Finder/Spotlight arrive through the app
/// delegate, not `onOpenURL` — without this the OS launches us and the file is
/// silently ignored.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        OpenFileBroker.shared.deliver(urls)
    }
}
#endif
