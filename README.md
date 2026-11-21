# Keys — клавиатура для iOS с настройками

[![ci](https://github.com/syxmwii/keys/actions/workflows/ci.yml/badge.svg)](https://github.com/syxmwii/keys/actions/workflows/ci.yml)
[![release](https://github.com/syxmwii/keys/actions/workflows/release.yml/badge.svg)](https://github.com/syxmwii/keys/actions/workflows/release.yml)

Настоящая системная клавиатура (keyboard extension) + отдельное приложение с настройками.
Собирается в `.ipa` прямо в GitHub Actions — без Mac и без Xcode на твоей машине.

- **Раскладки:** English, Русский, цифры, символы, ряд цифр сверху.
- **Темы:** 8 пресетов + полностью свои цвета (фон, клавиши, текст, акцент, обводка).
- **Клавиши:** высота, скругление, зазор, размер букв, тень, обводка.
- **Отклик:** вибрация, звук нажатия, анимация, всплывающая буква.
- **Жесты:** свайп по пробелу двигает курсор, свайп по ⌫ стирает слово, удержание ⌫ повторяет удаление, двойной пробел ставит точку.
- **Эмодзи:** 9 категорий + недавние, отдельная панель.
- **Настройки в самой клавиатуре:** шестерёнка в панели эмодзи — тема, высота, звук, вибрация, ряд цифр. Работают даже без App Group.
- **Живой предпросмотр** в приложении: набираешь текст теми же клавишами, что и в системе.

---

## Установка

### Вариант 1 — готовый IPA из Actions

1. Открой [Actions](https://github.com/syxmwii/keys/actions/workflows/ci.yml) → последний зелёный запуск → артефакт **Keys-unsigned**.
2. Подпиши его на компьютере: [Sideloadly](https://sideloadly.io) (Windows/macOS), AltStore, Feather или TrollStore.
3. Установи на iPhone.

### Вариант 2 — подписанный из релиза

Если в репозитории заведены секреты подписи (см. ниже), на теге `v*` собирается
релиз с уже подписанным `Keys-signed.ipa` — его можно ставить без Sideloadly.

### После установки

1. **Настройки → Основные → Клавиатура → Клавиатуры → Новые клавиатуры → Keys** — включить.
2. Полный доступ не обязателен, но с ним настройки долетают до клавиатуры сразу.
3. В любом поле ввода удерживай 🌐, пока не появится Keys.

---

## Настройки и App Group

Приложение и расширение общаются через App Group `group.app.syxmwii.keys`.
Это требует подписи с entitlements — то есть **подписанной** сборки.

Что происходит в неподписанной сборке:

- клавиатура работает, но с дефолтными значениями (Midnight, 50 pt, вибрация вкл.);
- приложение показывает предупреждение «Настройки не синхронизируются»;
- ничего не падает: `SettingsStore` пишет и в App Group, и в обычные `UserDefaults`,
  читает сначала из группы.

Чтобы настроить клавиатуру в этом режиме: открой панель эмодзи → шестерёнка
(`slider.horizontal.3`) → тема, высота, звук, вибрация, ряд цифр. Настройки
сохраняются в контейнере расширения и переживают перезапуск.

Если подписываешь Sideloadly/AltStore своим Apple ID — включи в подписи
capability **App Groups** (Sideloadly делает это автоматически для entitlements
из `.mobileprovision`) и всё заработает.

---

## Сборка

Нужен macOS + Xcode 16 + [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
make build          # → build/Keys.ipa (неподписанный)
make test           # тесты на симуляторе
make icon           # перегенерировать иконку (Python + Pillow)
```

`project.yml` — единственный источник правды о проекте, `.xcodeproj` генерируется
и в git не лежит.

### Подпись в Actions

`release.yml` подписывает IPA, если заданы секреты:

| Секрет | Что это |
| --- | --- |
| `KEYS_P12_B64` | `.p12` сертификата в base64 |
| `KEYS_P12_PASSWORD` | пароль от `.p12` |
| `KEYS_PROFILE_B64` | `.mobileprovision` для `app.syxmwii.keys` |
| `KEYS_EXT_PROFILE_B64` | `.mobileprovision` для `app.syxmwii.keys.keyboard` |

```bash
base64 -i cert.p12 | gh secret set KEYS_P12_B64 -R syxmwii/keys
base64 -i app.mobileprovision | gh secret set KEYS_PROFILE_B64 -R syxmwii/keys
base64 -i keyboard.mobileprovision | gh secret set KEYS_EXT_PROFILE_B64 -R syxmwii/keys
```

Профили обязаны содержать **оба** bundle id и App Group — иначе установка упадёт
на проверке подписи расширения. `scripts/sign-ipa.sh` вытаскивает entitlements
из профиля и подписывает сначала `.appex`, потом приложение.

---

## Структура

```
Sources/
  Shared/            # общий код приложения и расширения
    Layout.swift     # раскладки, KeySpec, сборка строк, высота
    Settings.swift   # KeysSettings + SettingsStore (App Group)
    Theme.swift      # палитры, пресеты, hex ↔ UIColor/Color
    EmojiCatalog.swift
    UIKitSupport.swift  # вибрация, звук, контраст текста
  Keyboard/
    KeyboardViewController.swift  # вся логика ввода, свайпы, альтернаты
    KeyboardView.swift            # ручная раскладка клавиш + попап
    KeyView.swift                 # клавиша: tap / long press / repeat / swipe
    EmojiPanelView.swift
  App/
    SettingsView.swift   # настройки
    PreviewKeyboard.swift# предпросмотр на тех же KeySpec
    ThemeEditorView.swift
    SetupView.swift
Tests/LayoutTests.swift
scripts/{build-ipa,sign-ipa}.sh, make-icon.py
.github/workflows/{ci,release}.yml
```

## Что дальше

- [ ] Предиктивный ввод и словарь (RU/EN)
- [ ] Свайп-ввод по буквам
- [ ] Свои раскладки через JSON
- [ ] Темы с картинкой на фоне
- [ ] Тактильные профили (сила/длительность)

## Лицензия

MIT.