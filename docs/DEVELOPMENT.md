# Development guidelines

## Source map

- `main.swift`: catalog/models, persistence, library UI, app lifecycle, menus, and test entry point.
- `PreviewLayout.swift`: adaptive widths, explicit Core Text line positioning, overlay rendering.
- `Appearance.swift`: palette, native popups, glass/fallback surfaces, sidebar sections.
- `FontInspector.swift`: family styles, variable tuning, OpenType, body layout and font context.
- `LibraryTools.swift`: tags, grouping, duplicates, activation UI, Google downloads/previews.
- `ProModels.swift`: metadata parsing, advanced filters, activation journal, duplicate hashing, exports.
- `FolderAccess.swift`: security-scoped bookmarks.
- `Features.swift`: script coverage probes, comparison and manual Adobe script export.
- `ProChecks.swift`: persistence and feature regressions.

## Invariants

- Preserve the user's font files and library data. Surface failures; do not overwrite unreadable state with defaults.
- Keep font size literal. Make space for text through wrapping/layout, not silent shrinking or clipping in library cards.
- Align actual baselines. Distinct ascenders, descenders and glyph shapes are not interchangeable with a view's top edge.
- Keep the toolbar readable and the sidebar's glass native. Use availability checks and respect accessibility preferences.
- UI copy must be concise and functional; no taglines or decorative filler.
- Preview downloads must not activate fonts or modify the library. Keep preview text on-device.
- Maintain sandbox compatibility and explicit user-selected file access. Adobe support is script export only.
- Update both version plists. App bundle display name remains FontShelf; release ZIPs carry versions.

Keep source-only changes separate from generated artifacts. The `.gitignore` excludes local output and private state. Use Xcode's complete bundle for distribution rather than relying on the source-only Swift package.
