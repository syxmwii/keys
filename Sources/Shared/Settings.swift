import Combine
import Foundation
import SwiftUI

// MARK: - Модель настроек

public struct KeysSettings: Codable, Equatable {
    public var theme: ThemePreset
    public var custom: ThemeColors

    public var keyHeight: Double
    public var cornerRadius: Double
    public var keyGap: Double
    public var fontSize: Double

    public var showBorders: Bool
    public var showShadow: Bool
    public var keyPopup: Bool

    public var haptics: Bool
    public var sound: Bool
    public var bounce: Bool

    public var suggestions: Bool
    public var correctTypos: Bool
    public var detectLayout: Bool
    public var autocapitalize: Bool
    public var doubleSpacePeriod: Bool
    public var spaceCursor: Bool
    public var swipeBackspace: Bool
    public var deleteRepeat: Bool
    public var numberRow: Bool

    public var showEmojiKey: Bool
    public var showDismissKey: Bool

    public var enabledLayouts: [KeyboardLayoutID]
    public var lastLayout: KeyboardLayoutID
    public var emojiRecents: [String]

    public init() {
        theme = .midnight
        custom = ThemePreset.custom.colors
        keyHeight = 50
        cornerRadius = 8
        keyGap = 5
        fontSize = 19
        showBorders = false
        showShadow = true
        keyPopup = true
        haptics = true
        sound = true
        bounce = true
        suggestions = true
        correctTypos = true
        detectLayout = true
        autocapitalize = true
        doubleSpacePeriod = true
        spaceCursor = true
        swipeBackspace = true
        deleteRepeat = true
        numberRow = false
        showEmojiKey = true
        showDismissKey = true
        enabledLayouts = [.english, .russian]
        lastLayout = .english
        emojiRecents = []
    }

    /// Терпимое декодирование: новые поля не ломают старые настройки.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = KeysSettings()
        theme = try container.decodeIfPresent(ThemePreset.self, forKey: .theme) ?? defaults.theme
        custom = try container.decodeIfPresent(ThemeColors.self, forKey: .custom) ?? defaults.custom
        keyHeight = try container.decodeIfPresent(Double.self, forKey: .keyHeight) ?? defaults.keyHeight
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        keyGap = try container.decodeIfPresent(Double.self, forKey: .keyGap) ?? defaults.keyGap
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? defaults.fontSize
        showBorders = try container.decodeIfPresent(Bool.self, forKey: .showBorders) ?? defaults.showBorders
        showShadow = try container.decodeIfPresent(Bool.self, forKey: .showShadow) ?? defaults.showShadow
        keyPopup = try container.decodeIfPresent(Bool.self, forKey: .keyPopup) ?? defaults.keyPopup
        haptics = try container.decodeIfPresent(Bool.self, forKey: .haptics) ?? defaults.haptics
        sound = try container.decodeIfPresent(Bool.self, forKey: .sound) ?? defaults.sound
        bounce = try container.decodeIfPresent(Bool.self, forKey: .bounce) ?? defaults.bounce
        suggestions = try container.decodeIfPresent(Bool.self, forKey: .suggestions) ?? defaults.suggestions
        correctTypos = try container.decodeIfPresent(Bool.self, forKey: .correctTypos) ?? defaults.correctTypos
        detectLayout = try container.decodeIfPresent(Bool.self, forKey: .detectLayout) ?? defaults.detectLayout
        autocapitalize = try container.decodeIfPresent(Bool.self, forKey: .autocapitalize) ?? defaults.autocapitalize
        doubleSpacePeriod = try container.decodeIfPresent(Bool.self, forKey: .doubleSpacePeriod) ?? defaults.doubleSpacePeriod
        spaceCursor = try container.decodeIfPresent(Bool.self, forKey: .spaceCursor) ?? defaults.spaceCursor
        swipeBackspace = try container.decodeIfPresent(Bool.self, forKey: .swipeBackspace) ?? defaults.swipeBackspace
        deleteRepeat = try container.decodeIfPresent(Bool.self, forKey: .deleteRepeat) ?? defaults.deleteRepeat
        numberRow = try container.decodeIfPresent(Bool.self, forKey: .numberRow) ?? defaults.numberRow
        showEmojiKey = try container.decodeIfPresent(Bool.self, forKey: .showEmojiKey) ?? defaults.showEmojiKey
        showDismissKey = try container.decodeIfPresent(Bool.self, forKey: .showDismissKey) ?? defaults.showDismissKey
        enabledLayouts = try container.decodeIfPresent([KeyboardLayoutID].self, forKey: .enabledLayouts) ?? defaults.enabledLayouts
        lastLayout = try container.decodeIfPresent(KeyboardLayoutID.self, forKey: .lastLayout) ?? defaults.lastLayout
        emojiRecents = try container.decodeIfPresent([String].self, forKey: .emojiRecents) ?? defaults.emojiRecents

        if enabledLayouts.isEmpty {
            enabledLayouts = defaults.enabledLayouts
        }
        if !enabledLayouts.contains(lastLayout) {
            lastLayout = enabledLayouts[0]
        }
    }

    public var colors: ThemeColors {
        theme == .custom ? custom : theme.colors
    }

    // MARK: Эмодзи

    public mutating func rememberEmoji(_ emoji: String) {
        var recents = emojiRecents.filter { $0 != emoji }
        recents.insert(emoji, at: 0)
        emojiRecents = Array(recents.prefix(32))
    }
}

// MARK: - Хранилище

public extension Notification.Name {
    static let keysSettingsChanged = Notification.Name("keys.settings.changed")
}

/// Единое хранилище настроек приложения и расширения клавиатуры.
///
/// Пишет в App Group и в стандартные UserDefaults, читает — сначала из группы.
/// Если сборка не подписана с App Group (неподписанный IPA / локальный сайдлоад),
/// запись в группу просто отбрасывается, и каждый процесс живёт со своими
/// настройками. Это деградирует мягко: клавиатура остаётся рабочей.
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    public static let appGroupID = "group.app.syxmwii.keys"
    private static let storageKey = "keys.settings.v1"
    private static let probeKey = "keys.group.probe"

    private let group: UserDefaults?
    private let standard = UserDefaults.standard

    /// true, если App Group реально доступна и настройки долетают до клавиатуры.
    public private(set) var sharesWithKeyboard: Bool

    @Published public var settings: KeysSettings

    private var cancellable: AnyCancellable?

    public init(suiteName: String = SettingsStore.appGroupID) {
        group = UserDefaults(suiteName: suiteName)

        var loaded: KeysSettings?
        if let data = group?.data(forKey: Self.storageKey) {
            loaded = try? JSONDecoder().decode(KeysSettings.self, from: data)
        }
        if loaded == nil, let data = standard.data(forKey: Self.storageKey) {
            loaded = try? JSONDecoder().decode(KeysSettings.self, from: data)
        }
        settings = loaded ?? KeysSettings()

        group?.set(true, forKey: Self.probeKey)
        sharesWithKeyboard = group?.bool(forKey: Self.probeKey) == true
        group?.removeObject(forKey: Self.probeKey)

        // Сохраняем на каждое изменение, но не на первичную загрузку.
        cancellable = $settings
            .dropFirst()
            .sink { [weak self] _ in
                self?.persist()
            }
    }

    public func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        group?.set(data, forKey: Self.storageKey)
        standard.set(data, forKey: Self.storageKey)
        NotificationCenter.default.post(name: .keysSettingsChanged, object: nil)
    }

    /// Перечитать настройки из общего контейнера (клавиатура вызывает на показе).
    public func reload() {
        guard let data = group?.data(forKey: Self.storageKey) ?? standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(KeysSettings.self, from: data)
        else { return }
        if decoded != settings {
            settings = decoded
        }
    }

    public func reset() {
        settings = KeysSettings()
    }

    public func toggleLayout(_ layout: KeyboardLayoutID) {
        var enabled = settings.enabledLayouts
        if let index = enabled.firstIndex(of: layout) {
            guard enabled.count > 1 else { return }
            enabled.remove(at: index)
        } else {
            enabled.append(layout)
        }
        settings.enabledLayouts = enabled
        if !enabled.contains(settings.lastLayout) {
            settings.lastLayout = enabled[0]
        }
    }
}