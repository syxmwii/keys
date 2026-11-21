#!/usr/bin/env bash
# Собирает НЕПОДПИСАННЫЙ build/Keys.ipa (macOS + Xcode + xcodegen).
# Используется и локально, и в GitHub Actions.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Keys"
BUILD_DIR="build"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "нужен xcodegen: brew install xcodegen" >&2
  exit 1
fi

echo "==> xcodegen"
xcodegen generate --spec project.yml

echo "==> xcodebuild archive (без подписи)"
rm -rf "$BUILD_DIR/$APP_NAME.xcarchive" "$BUILD_DIR/ipa" "$BUILD_DIR/$APP_NAME.ipa"
mkdir -p "$BUILD_DIR"

xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive

APP="$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP" ]; then
  echo "не нашёл $APP" >&2
  exit 1
fi

if [ ! -d "$APP/PlugIns/KeysKeyboard.appex" ]; then
  echo "в сборке нет расширения KeysKeyboard.appex — клавиатура не установится" >&2
  exit 1
fi

echo "==> упаковка IPA"
mkdir -p "$BUILD_DIR/ipa/Payload"
cp -R "$APP" "$BUILD_DIR/ipa/Payload/"
(cd "$BUILD_DIR/ipa" && zip -qry "../$APP_NAME.ipa" Payload)

echo "==> проверка"
unzip -l "$BUILD_DIR/$APP_NAME.ipa" | grep -E "PlugIns|Keys$" | head -5

echo "Готово: $BUILD_DIR/$APP_NAME.ipa (неподписанный)"