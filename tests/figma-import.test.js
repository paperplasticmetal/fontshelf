const assert = require('node:assert/strict');
const { validate, importLayout } = require('../Resources/FigmaImport/code.js');
const black = { r: 0, g: 0, b: 0, a: 1 };
function fixture() { return { format: 'fontshelf-figma', version: 1, name: 'Client', frames: [{ name: 'A', width: 390, height: 800, paper: black, elements: [{ kind: 'text', section: 'Hero', role: 'Display', x: 24, y: 24, width: 342, height: 140, text: 'Editable text', fontFamily: 'Georgia', fontStyle: 'Regular', fontSize: 64, lineHeight: 80, letterSpacing: 1, paragraphSpacing: 12, paragraphIndent: 0, alignment: 'CENTER', color: black, axes: {}, features: {}, kerning: true }] }] }; }
function mock(failFont = false, failText = false) {
  const frames = [];
  function node() { return { children: [], removed: false, resize(w, h) { this.width = w; this.height = h; }, appendChild(n) { this.children.push(n); }, remove() { this.removed = true; }, setPluginData(k, v) { this[k] = v; } }; }
  return { frames, currentPage: { selection: [] }, viewport: { center: { x: 0, y: 0 }, scrollAndZoomIntoView() {} }, createFrame() { const n = node(); frames.push(n); return n; }, createText() { if (failText) throw Error('simulated creation failure'); return node(); }, createRectangle: node, async loadFontAsync(font) { if (failFont && font.family !== 'Inter') throw Error('missing font'); } };
}
(async () => {
  const data = fixture(); validate(data);
  const api = mock(); const result = await importLayout(data, api);
  assert.match(result, /1 editable frames/); assert.equal(api.frames[0].children[0].characters, 'Editable text'); assert.equal(api.frames[0].children[0].textAlignHorizontal, 'CENTER'); assert.equal(api.frames[0].children[0].lineHeight.value, 80); assert.equal(api.currentPage.selection.length, 1);
  const missing = mock(true); assert.match(await importLayout(data, missing), /Missing font/); assert.equal(missing.frames[0].children[0].fontName.family, 'Inter');
  const failing = mock(false, true); await assert.rejects(importLayout(data, failing), /simulated/); assert(failing.frames.every(f => f.removed));
  const invalid = fixture(); invalid.frames[0].elements[0].width = -1; const clean = mock(); await assert.rejects(importLayout(invalid, clean), /bounds/); assert.equal(clean.frames.length, 0);
  const warn = fixture(); warn.frames[0].elements[0].wordSpacing = 3; assert.match(await importLayout(warn, mock()), /manual|Review/);
  console.log('PASS: editable layers, typography, missing-font fallback, validation and rollback. Figma API mocked; live editor validation remains separate.');
})().catch(error => { console.error(error); process.exitCode = 1; });
