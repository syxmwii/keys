import SwiftUI

/// Shared surfaces for the main settings, onboarding and palette editor.
struct SettingsList<Content: View>: View {
    @EnvironmentObject private var store: SettingsStore
    @ViewBuilder let content: () -> Content

    var body: some View {
        let settings = store.settings
        if settings.design == .classic {
            List { content() }
                .listStyle(.insetGrouped)
        } else {
            List {
                content()
                    .listRowBackground(settings.colors.swiftKey)
                    .listRowSeparatorTint(settings.colors.swiftBorder)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(settings.colors.swiftBackground)
            .foregroundStyle(settings.colors.swiftText)
            .fontDesign(settings.design == .mechanical ? .monospaced : .rounded)
            .toolbarBackground(settings.colors.swiftBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

enum SettingsPage: String, CaseIterable {
    case appearance = "Вид"
    case typing = "Ввод"
    case setup = "Настройка"

    var symbol: String {
        switch self {
        case .appearance: return "paintpalette"
        case .typing: return "keyboard"
        case .setup: return "gearshape"
        }
    }
}

struct SettingsNavigation: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Binding var page: SettingsPage

    var body: some View {
        let settings = store.settings
        let native = settings.design == .classic
        HStack(spacing: 4) {
            ForEach(SettingsPage.allCases, id: \.self) { destination in
                let selected = page == destination
                Button {
                    page = destination
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: destination.symbol)
                            .font(.body.weight(selected ? .semibold : .regular))
                        Text(destination.rawValue).font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background {
                        if selected {
                            Capsule().fill(native ? Color.primary.opacity(0.12) : settings.colors.swiftAccent)
                        }
                    }
                    .foregroundStyle(ink(selected: selected, native: native))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(5)
        .background { surface(native: native) }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func ink(selected: Bool, native: Bool) -> Color {
        if native { return .primary }
        let colors = store.settings.colors
        return selected ? Color(uiColor: colors.uiAccent.keysContrastingText) : colors.swiftText
    }

    @ViewBuilder private func surface(native: Bool) -> some View {
        if native {
            if reduceTransparency {
                Capsule().fill(Color(uiColor: .secondarySystemGroupedBackground))
            } else {
                #if compiler(>=6.2)
                if #available(iOS 26.0, *) {
                    Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
                } else {
                    Capsule().fill(.regularMaterial)
                }
                #else
                Capsule().fill(.regularMaterial)
                #endif
            }
        } else {
            RoundedRectangle(cornerRadius: store.settings.design == .mechanical ? 8 : 24)
                .fill(store.settings.colors.swiftModifier)
        }
    }
}
