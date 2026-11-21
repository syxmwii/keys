import SwiftUI
import UIKit

@main
struct KeysApp: App {
    @StateObject private var store = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environmentObject(store)
                .tint(store.settings.colors.swiftAccent)
                .preferredColorScheme(store.settings.theme.isLight ? .light : .dark)
        }
    }
}