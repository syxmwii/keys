import SwiftUI
import UIKit

struct SetupView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                step(
                    number: 1,
                    title: "Открой системные настройки",
                    detail: "Основные → Клавиатура → Клавиатуры → Новые клавиатуры"
                )
                step(
                    number: 2,
                    title: "Включи Keys",
                    detail: "Найди «Keys» в разделе «Сторонние клавиатуры» и включи переключатель."
                )
                step(
                    number: 3,
                    title: "Разреши полный доступ (по желанию)",
                    detail: "Нужен, чтобы клавиатура читала настройки из общего контейнера сразу после изменения."
                )
                step(
                    number: 4,
                    title: "Переключись на неё",
                    detail: "В любом поле ввода удерживай 🌐 или нажми на него, пока не появится Keys."
                )
            } header: {
                Text("Включение")
            } footer: {
                Text("Без полного доступа клавиатура тоже работает — просто не видит изменения настроек, пока не перезапустится.")
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Открыть Настройки", systemImage: "gear")
                }
            }

            Section("Подсказки") {
                tip("Долгое нажатие на букву даёт варианты с диакритикой (для English).")
                tip("Свайп влево по пробелу двигает курсор по символу.")
                tip("Свайп влево по ⌫ стирает слово, удержание — повторяет удаление.")
                tip("Двойной пробел ставит точку и пробел.")
                tip("Клавиша ⌄ в правом нижнем углу скрывает клавиатуру.")
            }

            Section {
                Text("Keys — open-source клавиатура, собранная в GitHub Actions. Настройки хранятся только на устройстве.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Как включить")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private func tip(_ text: String) -> some View {
        Label {
            Text(text).font(.footnote)
        } icon: {
            Image(systemName: "lightbulb")
                .foregroundStyle(.yellow)
        }
    }
}