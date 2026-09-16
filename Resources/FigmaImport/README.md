# FontShelf → Figma

This package contains an editable layout JSON file and a local Figma development importer. It makes no network requests, uploads no fonts and does not modify existing layers.

1. In Figma desktop, use Plugins → Development → Import plugin from manifest and select this folder's `manifest.json`.
2. Run FontShelf Layout Importer. Choose `layout.fontshelf.json`, then Import layouts. No assigned plugin ID or public publication is required.
3. Each saved direction becomes a separate frame, with editable text and shapes. Review the importer report for missing fonts or unsupported settings.

Keep the original fonts available to Figma. Missing fonts fall back to Inter with an explicit warning. FontShelf does not redistribute font files or licenses.

Original typography settings are kept as shared layer metadata under the `fontshelf` namespace, readable by other plugins in that Figma document. No private notes, font files or local paths are stored in this metadata.

Positions, sizes, colors, alignment, line height, tracking, paragraph spacing, indents and basic decorations are transferred. Variable axes are applied when supported by your Figma version. Word spacing, custom kerning and OpenType overrides are retained as layer metadata but require manual review. Figma's text shaping and wrapping may differ from macOS. This is a one-way local handoff, not live sync or a published Figma integration.
