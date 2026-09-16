# Interaction checks — 0.16.0

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
