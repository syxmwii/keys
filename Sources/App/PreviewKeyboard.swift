import SwiftUI

/// Живой предпросмотр клавиатуры внутри приложения: те же строки, те же веса
/// клавиш и та же тема, что и в расширении.
struct PreviewKeyboard: View {
    let settings: KeysSettings
    @Binding var text: String

    @State private var plane: KeyPlane = .letters
    @State private var shift = false
    @State private var caps = false
    @State private var layout: KeyboardLayoutID

    init(settings: KeysSettings, text: Binding<String>) {
        self.settings = settings
        self._text = text
        self._layout = State(initialValue: settings.lastLayout)
    }

    private var colors: ThemeColors { settings.colors }

    var body: some View {
        let rows = KeyboardRows.rows(
            layout: layout,
            plane: plane,
            shift: shift,
            caps: caps,
            settings: settings,
            enabledLayouts: settings.enabledLayouts,
            showGlobe: false,
            returnKey: "return"
        )

        VStack(spacing: CGFloat(KeyboardRows.verticalGap)) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
        }
        .padding(.horizontal, KeyboardRows.sidePadding)
        .padding(.top, KeyboardRows.topPadding)
        .padding(.bottom, KeyboardRows.bottomPadding)
        .background(colors.swiftBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func rowView(_ row: [KeySpec]) -> some View {
        GeometryReader { geometry in
            let gap = CGFloat(settings.keyGap)
            let available = geometry.size.width - CGFloat(max(row.count - 1, 0)) * gap
            let total = max(row.reduce(CGFloat(0)) { $0 + $1.width }, 0.1)

            HStack(spacing: gap) {
                ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                    PreviewKeyView(spec: key, colors: colors, settings: settings)
                        .frame(width: max(available * key.width / total, 14))
                        .onTapGesture { perform(key.action) }
                }
            }
        }
        .frame(height: CGFloat(settings.keyHeight))
    }

    private func perform(_ action: KeyAction) {
        if settings.haptics {
            KeyFeedback.press(haptics: true, sound: false)
        }
        switch action {
        case .character(let character):
            text += (shift || caps) ? character.uppercased() : character
            if !caps { shift = false }
        case .backspace:
            if !text.isEmpty { text.removeLast() }
        case .space:
            text += " "
        case .newline:
            text += "\n"
        case .shift:
            if caps {
                caps = false
                shift = false
            } else if shift {
                shift = false
                caps = true
            } else {
                shift = true
            }
        case .plane(let target):
            plane = target
        case .layout:
            let enabled = settings.enabledLayouts
            if let index = enabled.firstIndex(of: layout) {
                layout = enabled[(index + 1) % enabled.count]
            } else {
                layout = enabled.first ?? .english
            }
            shift = false
            caps = false
        case .emoji, .globe, .dismiss, .none:
            break
        }
    }
}

private struct PreviewKeyView: View {
    let spec: KeySpec
    let colors: ThemeColors
    let settings: KeysSettings

    private var background: Color {
        switch spec.style {
        case .normal: return colors.swiftKey
        case .modifier: return colors.swiftModifier
        case .accent: return colors.swiftAccent
        }
    }

    private var foreground: Color {
        guard spec.style == .accent else { return colors.swiftText }
        return UIColor(hex: colors.accent)?.keysContrastingText == .black ? .black : .white
    }

    private var fontSize: CGFloat {
        switch spec.style {
        case .normal: return CGFloat(settings.fontSize)
        case .modifier: return max(CGFloat(settings.fontSize) * 0.72, 10)
        case .accent: return max(CGFloat(settings.fontSize) * 0.78, 11)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat(settings.cornerRadius), style: .continuous)
                .fill(background)

            if let symbol = spec.symbol {
                Image(systemName: symbol)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(foreground)
            } else {
                Text(spec.label)
                    .font(.system(size: fontSize, weight: spec.style == .normal ? .regular : .medium))
                    .foregroundColor(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 2)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(settings.cornerRadius), style: .continuous)
                .strokeBorder(settings.showBorders ? colors.swiftBorder : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}