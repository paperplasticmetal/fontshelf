#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="dist/FontShelf.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/module-cache
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
cp Resources/GoogleVariableFonts.json "$APP/Contents/Resources/GoogleVariableFonts.json"
swiftc -warnings-as-errors -swift-version 5 -O -module-cache-path .build/module-cache -target arm64-apple-macosx13.0 Sources/*.swift -o "$APP/Contents/MacOS/FontShelf"
codesign --force --deep --sign - "$APP"
"$APP/Contents/MacOS/FontShelf" --self-test
