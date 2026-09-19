# Interaction checks — 0.16.0

## 0.18.0 follow-up

Verified the developer handoff exports every canvas into a local package with production CSS, variable axes and OpenType features, Tailwind v3/v4 configuration, versioned JSON tokens, preload examples, SwiftUI and Android Compose starter definitions, exact source-board data, and a standalone printable HTML specimen. The generated Swift file type-checks and the Tailwind configuration parses with every exported style. Font files are never copied; the manifest calls out licensing and required assets, while the specimen can use an already-installed local font for review.

Project, typeboard, and collection names now edit directly in place without pencil buttons. Clicking a selected name enters editing immediately with the current name selected; Return saves and Escape cancels. An unselected sidebar name selects on first click and edits on double-click. Live checks covered sidebar and header editing, keyboard focus, saving, project synchronization, and duplicate collection-name protection. The empty QA collection created for these checks was removed afterward; the user's existing collection and projects were not changed.

## 0.17.0 follow-up

Also verified the Add & Watch picker explains recursive updates, choosing a temporary empty folder opens Watched folders automatically, and the new entry has activation off by default. Stopped watching only that temporary test folder afterward; the user's three existing watches were left unchanged. Verified 200% canvas zoom through the menu and return to Fit. Library scanning can queue newly chosen folders instead of disabling the picker.

Live-checked visible canvas tabs and Show all canvases on a two-canvas board; exact canvas button-label selection into the UI label editor; editing that label without changing the headline, followed by Undo; the existing Portfolio Site collection filtering the font chooser to 14 styles; and the persistent trash action opening confirmation for an unselected board (cancelled without deleting it). The Library live-folders shortcut is visible. Regression checks cover collection/category intersection, manual category overrides, favorites, exact role hit-testing, selected-text serialization/rendering, legacy naming and zoom bounds.

Pinch and Command-scroll handlers are implemented with viewport-limited native event monitoring. Physical trackpad gesture feel has not been verified by automation. Native `.fig` decoding remains unimplemented: Figma's [local-copy guide](https://help.figma.com/hc/en-us/articles/8403626871063-Save-a-local-copy-of-files) and [import guide](https://help.figma.com/hc/en-us/articles/360041003114-Import-files-to-the-file-browser) describe reopening the file in Figma; no supported local decoding contract was found during this pass. The in-app import menu explains the bridge workflow.

Tested on macOS 26.3, Apple Silicon, September 16, 2026. These checks cover the exercised paths, not every font, Figma document or accessibility configuration.

## Live checks

- Exported two FontShelf directions through the bundled development plugin into editable Figma frames. Inspected the headline's actual font, size, line height and fill in Figma, edited its size and restored it.
- Exported a selected Figma frame to JSON through the live plugin, saved it and imported it through FontShelf's file picker. Verified the original layout, text layers, Georgia headline and Helvetica body styles.
- Edited the imported headline to “From Figma, now editable.” directly in FontShelf. Dragged it on the canvas and verified Undo returned it to its original position.
- Deleted the imported test typeboard using its sidebar trash action and confirmation. Verified Cmd-Z restored the board, selection and edited text.
- Verified the space title no longer clips and Export/overflow controls no longer touch at both tested wide and narrower desktop widths. The enlarged font chooser remains opaque over the canvas and focuses search on opening.
- Verified native canvas section reordering, insertion at beginning/end, Undo/Redo, section removal/restoration, font searching, empty search results, font selection and font Undo.
- Verified the inspector divider width persists after relaunch.
- Verified imported text edits survive relaunch, native Arrangement-list drag ordering and Undo, Quick A/B selection and Cmd-backslash switching, and full numeric size-edit Undo/Redo after correcting native field-editor routing.

## Automated checks

- Swift regression suite: imported geometry/style persistence, legacy decoding, validation, typeboard deletion/restore, Undo coalescing, canvas layouts, fonts, tags, watched-folder protection and exports.
- Node plugin suite: Figma API mock covering editable text, shared metadata without an assigned plugin ID, missing fonts, rollback, reverse frame export, coordinate conversion and unsupported-vector warnings. This is separate from the live editor checks above.

## Design guidance

Applied Apple's guidance on [toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Undo and Redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo), and [drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop): group related actions, expose recoverable editing, label Undo actions, and give insertion feedback.

## Boundaries

The Figma bridge uses selected-frame JSON, not `.fig` decoding or live sync. Unsupported visual features are reported; this is not a full-fidelity Figma renderer. Full VoiceOver and every window-size/font combination have not been audited. App Store sandbox activation verification remains outstanding.
