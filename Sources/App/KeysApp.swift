import SwiftUI
import UIKit

@main
struct KeysApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var store = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environmentObject(store)
                .tint(store.settings.colors.swiftAccent)
                .preferredColorScheme(store.settings.design == .classic ? nil : (store.settings.theme.isLight ? .light : .dark))
                .onChange(of: phase) { _, newPhase in
                    if newPhase == .active { store.reload() }
                }
        }
    }
}