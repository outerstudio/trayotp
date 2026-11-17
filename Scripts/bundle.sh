#!/usr/bin/env bash
# Builds TrayOTP.app without Xcode: swift build + a hand-made bundle + codesign.
#
#   Scripts/bundle.sh                # debug build, ad-hoc signed
#   CONFIG=release Scripts/bundle.sh
#   UNIVERSAL=1 CONFIG=release Scripts/bundle.sh   # arm64 + x86_64
#
# UNIVERSAL=1 (arm64 + x86_64) needs full Xcode, so it is meant for CI.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-debug}"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="build/TrayOTP.app"

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c "$CONFIG" --product TrayOTP ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" --product TrayOTP ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/TrayOTP" "$APP/Contents/MacOS/TrayOTP"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Support/Info.plist > "$APP/Contents/Info.plist"
[[ -f Support/AppIcon.icns ]] && cp Support/AppIcon.icns "$APP/Contents/Resources/" || true
# Translations: <lang>.lproj folders with Localizable.strings (UI) and InfoPlist.strings (camera prompt).
cp -R Support/Localizations/*.lproj "$APP/Contents/Resources/"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  # Ad-hoc signature with hardened runtime: blocks code injection and debugger attach
  # without needing an Apple certificate.
  codesign --force --options runtime --entitlements Support/TrayOTP.entitlements --sign - "$APP"
else
  # Developer ID + hardened runtime, required for notarization.
  codesign --force --options runtime --timestamp --entitlements Support/TrayOTP.entitlements --sign "$SIGN_IDENTITY" "$APP"
fi

codesign --verify --strict "$APP"
echo "Built $APP ($CONFIG, signed: $SIGN_IDENTITY)"
