# Changelog

## 0.14.0 — 2026-09-16

- Added Spaces, pairing typeboards, independently saved directions, checkpoints and side-by-side comparisons.
- Added responsive website, product UI, editorial, poster, type-system and custom ordered-block previews, with seven editable typography roles, PDF export and portable space import/export.
- Added searchable Unicode and unencoded glyph browsing, metrics and outline views, SVG export/drag, waterfall previews and paginated specimen PDFs.
- Added nested tags and AND/OR/NOT tag filtering, a metadata table and individually confirmed exact-duplicate removal to Trash.
- Added recursive folder watching and opt-in session activation from original files, including replacement/removal reconciliation.
- Added daily local backups, merge-based restore and corrupt-workspace preservation.
- Added regression coverage for workspaces, checkpoints, tags, folder snapshots, glyphs, responsive canvases, PDF pagination and backup merge; separate live folder/activation checks.
- Fixed two development test-runner crashes: headless PDFKit initialization and an incorrectly shared backup-test directory. PDF checks now use Core Graphics and new test failures exit with an error message.

## 0.13.1 — 2026-09-15

- Replaced the generic Serif and Sans Serif category symbols with compact letterform icons rendered in their corresponding type styles.

## 0.13.0 — 2026-09-15

- Actual Google Fonts previews before downloading, with editable sample text and size.
- Memory-only remote font rendering, a bounded cache, limited parallel loads, and retry controls.
- Updated in-app disclosure for preview network requests.

## 0.12.3 — 2026-09-15

- Corrected View menu layout checkmarks and shortlist membership after family regrouping.
- Required a saved license before persisting Google font files.
- Reported duplicate-scan subfolder errors and displayed export feedback inside the inspector.
- Expanded regression checks to include multilingual and unusual text layout.

## 0.12.2 — 2026-09-15

- Replaced font-dependent text-field spacing with explicit Core Text baselines shared across grid rows and overlay layers.

## 0.12.0–0.12.1 — 2026-09-15

- Adaptive preview widths, equal-height cards within rows, and larger controls.
- All family styles visible together; per-family and library-wide overlay comparisons.
- Visible shortlist entry in the sidebar.

## Earlier development

Installed/imported font browsing, script/category filters, collections, tags, last import, variable tuning, OpenType inspection, body layouts, duplicate detection, export, temporary activation, Adobe script export, native menus, and theme/glass refinements.
