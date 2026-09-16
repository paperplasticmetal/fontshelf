# FontShelf

[![macOS build](https://github.com/paperplasticmetal/fontshelf/actions/workflows/build.yml/badge.svg)](https://github.com/paperplasticmetal/fontshelf/actions/workflows/build.yml)

Native macOS font browsing, previews, and organization, built with SwiftUI, AppKit, and Core Text.

**Current version: 0.13.0 (build 20).** Development release for Apple Silicon. App Store submission is in preparation; this is not an App Store-approved or notarized release.

## Features

- Browse installed fonts and user-selected font folders; search, sort, and filter by source, category, script, weight, and OpenType features.
- Editable previews with adjustable size, adaptive grids, wrapping, and aligned baselines.
- View every style in a family, tune variable axes, inspect OpenType features, and preview body text layouts.
- Cyan/orange overlay comparison within a family or across the library; a six-family comparison shortlist.
- Favorites, collections, multi-tagging, family grouping, last import, and duplicate detection.
- Google variable fonts with real previews before download. Preview text stays local; public font files are fetched from Google's repository on GitHub.
- Original-file export and temporary session activation. Adobe integration exports JSX scripts for manual use, not direct application control.
- Light/dark appearances, India yellow accents, and native Liquid Glass on supported macOS versions.

## Build and run

Requirements: an Apple Silicon Mac, full **Xcode 26 or later** selected as the active developer directory, and its command-line tools. The app declares macOS 13 as its minimum; older-OS testing remains outstanding. Intel binaries are not shipped.

```sh
git clone https://github.com/paperplasticmetal/fontshelf.git
cd fontshelf
./build.sh
open dist/FontShelf.app
```

The build creates an ad-hoc-signed local app and runs the built-in regression checks. No paid Apple account is required for this local build. To run the checks again:

```sh
dist/FontShelf.app/Contents/MacOS/FontShelf --self-test
```

For Xcode, open `FontShelf.xcodeproj` and select the shared **FontShelf** scheme. Build without distribution credentials:

```sh
xcodebuild -project FontShelf.xcodeproj -scheme FontShelf \
  -configuration Release -derivedDataPath .build/xcode \
  CODE_SIGNING_ALLOWED=NO build
```

`Package.swift` supports source-level development, but the scripts/Xcode target create the complete app bundle with icons, privacy manifest, and Google catalog.

## Sandbox and App Store

```sh
./build-sandbox.sh
```

This creates a separate sandbox/hardened-runtime development app in `dist/`. A Store release needs an active paid Developer team and a registered production bundle identifier:

```sh
TEAM_ID=YOUR_TEAM_ID APP_BUNDLE_ID=com.yourcompany.fontshelf ./archive-store.sh
```

That command archives only; it does not upload. Validate and distribute through Xcode Organizer. See [App Store readiness](docs/APP_STORE.md).

## Status and documentation

- [Build and verification status](docs/STATUS.md)
- [Changelog](CHANGELOG.md)
- [Contribution guidelines](CONTRIBUTING.md)
- [Security reporting](SECURITY.md)
- [Architecture and design guidelines](docs/DEVELOPMENT.md)
- [Privacy](docs/PRIVACY.md)
- [Third-party metadata](THIRD_PARTY_NOTICES.md)

The workflow badge reflects GitHub CI. Local checks and manual testing have narrower coverage than a complete device/OS test matrix; see the status page for limits.

## License

No open-source license has been granted at this time. All rights are reserved by the respective copyright holders, except as permitted by applicable law and GitHub's terms. Public visibility is not permission to redistribute the app or reuse its code. Font files retain their own licenses; no font binaries are bundled in this repository.
