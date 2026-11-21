import SwiftUI

struct ThemeEditorView: View {
    @EnvironmentObject private var store: SettingsStore

    private var colors: ThemeColors { store.settings.custom }

    var body: some View {
        SettingsList {
            Section {
                HStack(spacing: 8) {
                    swatch(colors.background)
                    swatch(colors.key)
                    swatch(colors.keyPressed)
                    swatch(colors.modifier)
                    swatch(colors.text)
                    swatch(colors.accent)
                    swatch(colors.border)
                }
                .frame(height: 44)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text("Палитра")
            } footer: {
                Text("Фон · клавиши · нажатие · служебные · текст · акцент · обводка")
            }

            Section {
                colorRow("Фон", keyPath: \.background)
                colorRow("Клавиши", keyPath: \.key)
                colorRow("Нажатая клавиша", keyPath: \.keyPressed)
                colorRow("Служебные клавиши", keyPath: \.modifier)
                colorRow("Текст", keyPath: \.text)
                colorRow("Акцент (return)", keyPath: \.accent)
                colorRow("Обводка", keyPath: \.border)
            } header: {
                Text("Цвета")
            } footer: {
                Text("Любое изменение включает тему Custom. Обводка видна, если включена в разделе «Клавиши».")
            }

            Section {
                Menu {
                    ForEach(ThemePreset.allCases.filter { $0 != .custom }) { preset in
                        Button(preset.title) {
                            store.settings.custom = preset.colors
                            store.settings.theme = .custom
                        }
                    }
                } label: {
                    Label("Взять из темы", systemImage: "square.on.square")
                }

                Button("Сбросить цвета") {
                    store.settings.custom = ThemePreset.custom.colors
                }
            }
        }
        .navigationTitle("Свои цвета")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorRow(_ title: String, keyPath: WritableKeyPath<ThemeColors, String>) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: { Color(hex: store.settings.custom[keyPath: keyPath]) },
                set: { newValue in
                    store.settings.custom[keyPath: keyPath] = newValue.hexString
                    store.settings.theme = .custom
                }
            ),
            supportsOpacity: false
        )
    }

    private func swatch(_ hex: String) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(hex: hex))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            )
    }
}