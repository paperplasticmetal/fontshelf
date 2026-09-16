#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
xcodebuild -version >/dev/null || { echo 'Full Xcode 26 or newer is required; Command Line Tools cannot create this archive.' >&2; exit 1; }
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer team identifier}"
: "${APP_BUNDLE_ID:?Set APP_BUNDLE_ID to your registered app identifier}"
case "$APP_BUNDLE_ID" in local.*|*\$*|*\ *|'') echo 'Use a registered production bundle identifier.' >&2; exit 1;; esac
xcodebuild -project FontShelf.xcodeproj -scheme FontShelf -configuration Release -destination 'generic/platform=macOS' -archivePath 'dist/FontShelf.xcarchive' DEVELOPMENT_TEAM="$TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$APP_BUNDLE_ID" SWIFT_TREAT_WARNINGS_AS_ERRORS=YES archive
echo 'Archive created. Validate and distribute through Xcode Organizer. Nothing has been uploaded.'
