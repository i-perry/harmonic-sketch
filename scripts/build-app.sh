#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/harmonic-sketch-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/private/tmp}/harmonic-sketch-swift-cache"
CONFIGURATION="${1:-release}"
swift build --disable-sandbox --cache-path "${TMPDIR:-/private/tmp}/harmonic-sketch-package-cache" -c "$CONFIGURATION"
APP="dist/${HARMONIC_APP_NAME:-Harmonic Sketch}.app"
BUNDLE_ID="${HARMONIC_APP_BUNDLE_ID:-dev.harmonicsketch.composer}"
mkdir -p "$APP/Contents/MacOS"
cp ".build/$CONFIGURATION/HarmonicSketch" "$APP/Contents/MacOS/HarmonicSketch"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>HarmonicSketch</string>
<key>CFBundleIdentifier</key><string>dev.harmonicsketch.composer</string>
<key>CFBundleName</key><string>Harmonic Sketch</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
printf 'Built %s\n' "$PWD/$APP"
