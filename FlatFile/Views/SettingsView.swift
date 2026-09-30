//
//  SettingsView.swift
//  FlatFile
//
//  Lean Settings: Philosophy (the About card) and the version line.
//  Same view as a sheet on iOS/iPad and as the Mac Settings window.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAbout = false
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showAbout()
                    } label: {
                        Label(AboutCopy.title, systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Philosophy")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
        #if os(macOS)
        // Without an explicit frame the List collapses to zero height inside
        // a macOS sheet or the Settings window.
        .frame(minWidth: 440, minHeight: 360)
        #endif
    }

    private func showAbout() {
        #if os(macOS)
        openWindow(id: AboutWindow.id)
        #else
        showingAbout = true
        #endif
    }
}
