#!/usr/bin/env bash
# Export APK release (beta) Android, lalu pasang ke HP kalau ada yang tersambung.
#
#   tools/export_android.sh            -> build/android/IntoTheLight-<versi>.apk
#   tools/export_android.sh --install  -> sekalian `adb install` ke HP (USB debugging)
#
# Sebelum kirim build baru ke tester, NAIKKAN version/code di export_presets.cfg
# (preset Android), kalau tidak HP menolak update di atas versi lama.
# Keystore rilis ada di ~/keystores (jangan di-commit, simpan backup-nya).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot 2.app/Contents/MacOS/Godot}"
SDK="/opt/homebrew/share/android-commandlinetools"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"

VERSION=$(awk -F'"' '/^\[preset.0.options\]/{p=1} p&&/^version\/name=/{print $2; exit}' export_presets.cfg)
CODE=$(awk -F'=' '/^\[preset.0.options\]/{p=1} p&&/^version\/code=/{print $2; exit}' export_presets.cfg)
OUT="build/android/IntoTheLight-${VERSION:-dev}.apk"
mkdir -p build/android

echo ">> export $OUT (versionCode $CODE)"
"$GODOT" --headless --path . --export-release "Android" "$OUT"
"$SDK/build-tools/35.0.1/apksigner" verify "$OUT"
ls -lh "$OUT"

if [[ "${1:-}" == "--install" ]]; then
	"$SDK/platform-tools/adb" install -r "$OUT"
fi
