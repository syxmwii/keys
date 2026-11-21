import SwiftUI

/// Живой предпросмотр клавиатуры внутри приложения: те же строки, те же веса
/// клавиш и та же тема, что и в расширении.
struct PreviewKeyboard: View {
    let settings: KeysSettings
    @Binding var text: String

    @State private var plane: KeyPlane = .letters
    @State private var shift = false
    @State private var shiftGesture = ShiftGesture()
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
                    Button {
                        perform(key.action)
                    } label: {
                        Text(key.label.isEmpty ? key.keyID : key.label)
                    }
                    .buttonStyle(PreviewCapButton(spec: key, settings: settings))
                    .frame(width: max(available * key.width / total, 1))
                }
            }
        }
        .frame(height: CGFloat(settings.keyHeight))
    }

    private func perform(_ action: KeyAction) {
        if settings.haptics {
            KeyFeedback.press(haptics: true, sound: false)
        }
        if action != .shift { shiftGesture.reset() }
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
            let state = shiftGesture.tap(at: ProcessInfo.processInfo.systemUptime, shifted: shift, locked: caps)
            shift = state.shift
            caps = state.caps
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

struct PreviewKeycap: UIViewRepresentable {
    let spec: KeySpec
    let settings: KeysSettings
    var pressed = false

    func makeUIView(context: Context) -> KeycapFace { KeycapFace() }

    func updateUIView(_ view: KeycapFace, context: Context) {
        view.configure(spec, settings: settings, theme: settings.colors)
        view.setPressed(pressed)
    }
}

private struct PreviewCapButton: ButtonStyle {
    let spec: KeySpec
    let settings: KeysSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let transform = pressed && settings.bounce && !reduceMotion ? settings.design.pressedTransform : .identity
        return PreviewKeycap(spec: spec, settings: settings, pressed: pressed)
            .transformEffect(transform)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: pressed)
            .contentShape(Rectangle())
            .accessibilityLabel(spec.label.isEmpty ? spec.keyID : spec.label)
    }
}
