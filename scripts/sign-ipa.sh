#!/usr/bin/env bash
# Подписывает неподписанный IPA: сертификат .p12 + .mobileprovision.
#
# Переменные:
#   P12_B64         — base64 от .p12 (обязательно)
#   P12_PASSWORD    — пароль от .p12 (обязательно)
#   PROFILE_B64     — base64 от .mobileprovision приложения (обязательно)
#   EXT_PROFILE_B64 — base64 от .mobileprovision расширения (очень желательно)
#   OUT             — имя выходного файла (по умолчанию Keys-signed.ipa)
#
# Профиль приложения должен быть выпущен для app.syxmwii.keys,
# профиль расширения — для app.syxmwii.keys.keyboard.
set -euo pipefail

INPUT=${1:?путь к неподписанному ipa}
OUT=${OUT:-Keys-signed.ipa}
: "${P12_B64:?нужен base64 .p12}" \
  "${P12_PASSWORD:?нужен пароль}" \
  "${PROFILE_B64:?нужен base64 .mobileprovision}"
EXT_PROFILE_B64=${EXT_PROFILE_B64:-}

WORK=$(mktemp -d)
KEYCHAIN="$WORK/sign.keychain-db"
trap 'security delete-keychain "$KEYCHAIN" 2>/dev/null || true; rm -rf "$WORK"' EXIT

unzip -q "$INPUT" -d "$WORK"
echo "$P12_B64" | base64 -d > "$WORK/cert.p12"
echo "$PROFILE_B64" | base64 -d > "$WORK/app.mobileprovision"

security create-keychain -p ci "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"
security unlock-keychain -p ci "$KEYCHAIN"
security import "$WORK/cert.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k ci "$KEYCHAIN" >/dev/null

IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN" | awk -F'"' '/[0-9]+\)/ {print $2; exit}')
if [ -z "$IDENTITY" ]; then
  echo "в .p12 нет identity для codesign" >&2
  exit 1
fi
echo "Подпись: $IDENTITY"

APP=$(echo "$WORK"/Payload/*.app)
APP_BUNDLE=$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")
PROFILE_APP_ID=$(security cms -D -i "$WORK/app.mobileprovision" \
  | plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null || echo "?")
echo "Приложение: $APP_BUNDLE, профиль: $PROFILE_APP_ID"

extract_entitlements() {
  local profile=$1
  local output=$2
  security cms -D -i "$profile" > "$WORK/profile.plist"
  plutil -extract Entitlements xml1 -o "$output" "$WORK/profile.plist"
}

sign_bundle() {
  local bundle=$1
  local profile=$2
  cp "$profile" "$bundle/embedded.mobileprovision"
  extract_entitlements "$profile" "$WORK/entitlements.plist"
  /usr/bin/codesign \
    --force \
    --sign "$IDENTITY" \
    --keychain "$KEYCHAIN" \
    --timestamp=none \
    --entitlements "$WORK/entitlements.plist" \
    "$bundle"
}

# 1. Расширения клавиатуры — до приложения.
if [ -d "$APP/PlugIns" ]; then
  for appex in "$APP/PlugIns/"*.appex; do
    [ -e "$appex" ] || continue
    if [ -n "$EXT_PROFILE_B64" ]; then
      echo "$EXT_PROFILE_B64" | base64 -d > "$WORK/ext.mobileprovision"
      sign_bundle "$appex" "$WORK/ext.mobileprovision"
    else
      echo "::warning::EXT_PROFILE_B64 не задан: подписываю расширение профилем приложения."
      echo "::warning::Скорее всего установка упадёт (bundle id расширения не входит в профиль)."
      sign_bundle "$appex" "$WORK/app.mobileprovision"
    fi
  done
fi

# 2. Само приложение.
sign_bundle "$APP" "$WORK/app.mobileprovision"

(cd "$WORK" && zip -qry "$OLDPWD/$OUT" Payload)

echo "Проверка подписи:"
/usr/bin/codesign -dv --verbose=2 "$APP" 2>&1 | grep -E "Identifier|TeamIdentifier" || true
echo "Готово: $OUT"