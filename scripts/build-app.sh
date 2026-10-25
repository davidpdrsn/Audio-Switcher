#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

app="$PWD/dist/Audio Switcher.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
# Keep the executable name and bundle ID from the Xcode build so an existing install, its
# Launch at Login registration and its process name all carry over.
cp "$BIN/AudioSwitcher" "$app/Contents/MacOS/Audio Switcher"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Audio Switcher</string>
<key>CFBundleIdentifier</key><string>com.davidpdrsn.Audio-Switcher</string>
<key>CFBundleName</key><string>Audio Switcher</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.3</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "Built $app"
