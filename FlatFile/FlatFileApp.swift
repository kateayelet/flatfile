//
//  FlatFileApp.swift
//  FlatFile
//
//  Created by Kate Ayelet Benediktsson on 4/6/26.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

extension Notification.Name {
    /// Posted when the user asks "What is FlatFile?" from the Home Screen
    /// quick action; the root view presents the About sheet.
    static let flatfileShowAbout = Notification.Name("flatfileShowAbout")
}

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set when the app cold-launches from the quick action; consumed by the
    /// root view once the UI exists (the notification would fire before anyone
    /// is listening).
    static var pendingShortcutType: String?

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem {
            Self.pendingShortcutType = item.type
        }
        // Keep the generated SwiftUI scene name so the window still appears;
        // we only attach a delegate to receive Home Screen quick actions.
        let config = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == AboutCopy.shortcutType {
            NotificationCenter.default.post(name: .flatfileShowAbout, object: nil)
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
}
#endif

@main
struct FlatFileApp: App {
    @State private var store = StoreManager()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { await store.start() }
        }
        #if os(macOS)
        .commands {
            AboutCommands()
        }
        #endif

        #if os(macOS)
        // Same card as the iOS sheet. Content-hugging so it reads as a real
        // About window. NOTE: SwiftUI sometimes ignores CommandGroup(.appInfo)
        // (FlatNote hit this); Settings > Philosophy is the backup path.
        Window(AboutCopy.title, id: AboutWindow.id) {
            AboutView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
        #endif
    }
}

#if os(macOS)
private struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(AboutCopy.title) {
                openWindow(id: AboutWindow.id)
            }
        }
    }
}
#endif

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
