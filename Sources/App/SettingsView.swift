import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var sample = "Привет, это Keys 👋\n"
    @State private var showReset = false

    private var settings: KeysSettings { store.settings }

    var body: some View {
        NavigationStack {
            List {
                if !store.sharesWithKeyboard {
                    shareWarning
                }
                previewSection
                designSection
                themeSection
                keysSection
                feedbackSection
                inputSection
                languageSection
                emojiSection
                setupSection
                resetSection
                aboutSection
            }
            .navigationTitle("Keys")
            .alert("Сбросить настройки?", isPresented: $showReset) {
                Button("Отмена", role: .cancel) {}
                Button("Сбросить", role: .destructive) { store.reset() }
            } message: {
                Text("Вернутся тема Midnight, высота 50 pt и все переключатели по умолчанию.")
            }
        }
    }

    // MARK: - Секции

    private var shareWarning: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Настройки не синхронизируются с клавиатурой")
                        .font(.subheadline.weight(.semibold))
                    Text("Сборка без App Group. Клавиатура будет работать со своими значениями по умолчанию.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Нажми на клавиши ниже", text: $sample, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
                    .font(.system(.body, design: .rounded))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )

                PreviewKeyboard(settings: settings, text: $sample)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        } header: {
            Text("Предпросмотр")
        } footer: {
            Text("Клавиши здесь работают: набери что-нибудь, чтобы проверить тему и высоту.")
        }
    }

    private var designSection: some View {
        Section("Стиль клавиш") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(KeycapDesign.allCases, id: \.self) { design in
                    designCard(design)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            if settings.design == .expressive {
                Picker("Фигурные клавиши", selection: $store.settings.expressiveDetail) {
                    ForEach(ExpressiveDetail.allCases, id: \.self) { detail in
                        Text(detail.title).tag(detail)
                    }
                }
            }
        }
    }

    private func designCard(_ design: KeycapDesign) -> some View {
        var sample = settings
        sample.selectDesign(design)
        let selected = settings.design == design
        return Button {
            store.settings.selectDesign(design)
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 3) {
                    PreviewKeycap(spec: KeySpec(label: "а", action: .character("а")), settings: sample)
                    if design == .expressive {
                        PreviewKeycap(spec: KeySpec(label: "", action: .emoji, style: .modifier, symbol: "face.smiling"), settings: sample)
                    }
                    PreviewKeycap(spec: KeySpec(label: "", action: .newline, style: .accent, symbol: "return"), settings: sample)
                }
                .frame(height: 36)
                .padding(5)
                .background(sample.colors.swiftBackground, in: RoundedRectangle(cornerRadius: 10))
                Text(design.title)
                    .font(.caption.weight(selected ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(3)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(design.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var themeSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ThemePreset.allCases) { preset in
                        ThemeChip(preset: preset, selected: settings.theme == preset) {
                            store.settings.theme = preset
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))

            NavigationLink {
                ThemeEditorView()
            } label: {
                Label("Свои цвета", systemImage: "paintpalette")
            }
        } header: {
            Text("Тема")
        } footer: {
            Text("Свои цвета включаются автоматически, как только меняешь любой цвет.")
        }
    }

    private var keysSection: some View {
        Section("Клавиши") {
            SliderRow(
                title: "Высота",
                value: $store.settings.keyHeight,
                range: 40...68,
                format: { "\(Int($0)) pt" }
            )
            SliderRow(
                title: "Скругление",
                value: $store.settings.cornerRadius,
                range: 2...16,
                format: { "\(Int($0)) pt" }
            )
            SliderRow(
                title: "Зазор",
                value: $store.settings.keyGap,
                range: 2...10,
                format: { "\(Int($0)) pt" }
            )
            SliderRow(
                title: "Размер букв",
                value: $store.settings.fontSize,
                range: 14...26,
                format: { "\(Int($0)) pt" }
            )
            Toggle("Обводка клавиш", isOn: $store.settings.showBorders)
            Toggle("Тень клавиш", isOn: $store.settings.showShadow)
        }
    }

    private var feedbackSection: some View {
        Section {
            Toggle("Вибрация", isOn: $store.settings.haptics)
            Toggle("Звук нажатия", isOn: $store.settings.sound)
            Toggle("Анимация нажатия", isOn: $store.settings.bounce)
            Toggle("Всплывающая буква", isOn: $store.settings.keyPopup)
        } header: {
            Text("Отклик")
        } footer: {
            Text("Вибрация и звук работают только при включённом тактильном отклике в системных настройках.")
        }
    }

    private var inputSection: some View {
        Section {
            Toggle("Подсказки слов", isOn: $store.settings.suggestions)
            Toggle("Исправление опечаток", isOn: $store.settings.correctTypos)
            Toggle("Язык по контексту", isOn: $store.settings.detectLayout)
            Toggle("Автозаглавные буквы", isOn: $store.settings.autocapitalize)
            Toggle("Точка по двойному пробелу", isOn: $store.settings.doubleSpacePeriod)
            Toggle("Курсор свайпом по пробелу", isOn: $store.settings.spaceCursor)
            Toggle("Удаление слова свайпом", isOn: $store.settings.swipeBackspace)
            Toggle("Удаление при удержании", isOn: $store.settings.deleteRepeat)
            Toggle("Ряд цифр сверху", isOn: $store.settings.numberRow)
        } header: {
            Text("Ввод")
        } footer: {
            Text("Свайп влево по пробелу двигает курсор, свайп влево по ⌫ стирает слово целиком.")
        }
    }

    private var languageSection: some View {
        Section {
            ForEach(KeyboardLayoutID.allCases) { layout in
                Toggle(isOn: Binding(
                    get: { settings.enabledLayouts.contains(layout) },
                    set: { _ in store.toggleLayout(layout) }
                )) {
                    HStack {
                        Text(layout.title)
                        Spacer()
                        Text(layout.badge)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(settings.enabledLayouts == [layout])
            }
        } header: {
            Text("Раскладки")
        } footer: {
            Text("Клавиша переключения появляется, если включено больше одной раскладки.")
        }
    }

    private var emojiSection: some View {
        Section {
            Toggle("Клавиша эмодзи", isOn: $store.settings.showEmojiKey)
            Toggle("Кнопка скрытия клавиатуры", isOn: $store.settings.showDismissKey)
            if !settings.emojiRecents.isEmpty {
                Button("Очистить недавние (\(settings.emojiRecents.count))", role: .destructive) {
                    store.settings.emojiRecents = []
                }
            }
        } header: {
            Text("Эмодзи")
        } footer: {
            Text("Недавние эмодзи появляются первой категорией в панели.")
        }
    }

    private var setupSection: some View {
        Section {
            NavigationLink {
                SetupView()
            } label: {
                Label("Как включить клавиатуру", systemImage: "keyboard")
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Сбросить настройки", role: .destructive) {
                showReset = true
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Версия", value: version)
            LabeledContent("Раскладки", value: settings.enabledLayouts.map(\.badge).joined(separator: " · "))
        } footer: {
            Text("Keys — клавиатура с настройками. Собрано в GitHub Actions.")
                .font(.caption)
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

// MARK: - Компоненты

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
        }
        .padding(.vertical, 2)
    }
}

private struct ThemeChip: View {
    let preset: ThemePreset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(preset.colors.swiftBackground)
                    .overlay(
                        HStack(spacing: 3) {
                            key(preset.colors.swiftKey)
                            key(preset.colors.swiftAccent)
                            key(preset.colors.swiftModifier)
                        }
                        .padding(6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                selected ? preset.colors.swiftAccent : Color.white.opacity(0.12),
                                lineWidth: selected ? 2 : 1
                            )
                    )
                    .frame(width: 74, height: 46)

                Text(preset.title)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.title)
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
    }

    private func key(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(height: 12)
    }
}