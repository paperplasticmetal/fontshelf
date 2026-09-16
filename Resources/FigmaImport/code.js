/* Local, network-free importer. It only creates new frames; existing nodes are untouched. */
function number(value, min, max) { return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max; }
function paint(c) {
  if (!c || !['r', 'g', 'b', 'a'].every(key => number(c[key], 0, 1))) throw Error('Invalid color.');
  return [{ type: 'SOLID', color: { r: c.r, g: c.g, b: c.b }, opacity: c.a }];
}
function validate(data) {
  if (!data || data.format !== 'fontshelf-figma' || data.version !== 1 || !Array.isArray(data.frames) || !data.frames.length || data.frames.length > 100) throw Error('Unsupported FontShelf layout.');
  for (const frame of data.frames) {
    if (!number(frame.width, 1, 100000) || !number(frame.height, 1, 100000) || typeof frame.name !== 'string' || !Array.isArray(frame.elements) || frame.elements.length > 5000) throw Error('Invalid frame.');
    paint(frame.paper);
    for (const e of frame.elements) {
      if (!['x', 'y'].every(k => number(e[k], 0, 100000)) || !['width', 'height'].every(k => number(e[k], 1, 100000))) throw Error('Invalid layer bounds.');
      paint(e.color);
      if (e.kind === 'text') {
        if (typeof e.text !== 'string' || e.text.length > 200000 || typeof e.fontFamily !== 'string' || typeof e.fontStyle !== 'string' || !number(e.fontSize, 1, 1000) || !number(e.lineHeight, 1, 1000) || !number(e.letterSpacing, -100, 100) || !number(e.paragraphSpacing, 0, 1000) || !number(e.paragraphIndent, 0, 1000) || !['LEFT', 'CENTER', 'RIGHT', 'JUSTIFIED'].includes(e.alignment)) throw Error('Invalid text layer.');
      } else if (e.kind !== 'rectangle' || !number(e.radius, 0, 1000)) throw Error('Invalid shape.');
    }
  }
}
async function importLayout(data, api) {
  validate(data);
  const created = [], warnings = new Set(), loaded = new Map();
  let x = api.viewport.center.x;
  try {
    for (const layout of data.frames) {
      const frame = api.createFrame(); created.push(frame);
      frame.name = data.name + ' / ' + layout.name; frame.resize(layout.width, layout.height);
      frame.x = x; frame.y = api.viewport.center.y; frame.fills = paint(layout.paper); frame.clipsContent = false;
      for (const e of layout.elements) {
        let node;
        if (e.kind === 'text') {
          const key = e.fontFamily + '\n' + e.fontStyle;
          if (!loaded.has(key)) {
            let font = { family: e.fontFamily, style: e.fontStyle };
            try { await api.loadFontAsync(font); }
            catch (_) { warnings.add('Missing font: ' + e.fontFamily + ' ' + e.fontStyle + ' → Inter Regular'); font = { family: 'Inter', style: 'Regular' }; await api.loadFontAsync(font); }
            loaded.set(key, font);
          }
          node = api.createText(); frame.appendChild(node);
          node.fontName = loaded.get(key);
          if (e.axes && Object.keys(e.axes).length && node.fontName.family === e.fontFamily) {
            try { node.fontName = { ...loaded.get(key), variationSettings: e.axes }; }
            catch (_) { warnings.add('Variable axes need manual review: ' + e.fontFamily); }
          }
          node.fontSize = e.fontSize; node.characters = e.text;
          node.lineHeight = { value: e.lineHeight, unit: 'PIXELS' };
          node.letterSpacing = { value: e.letterSpacing, unit: 'PIXELS' };
          node.paragraphSpacing = e.paragraphSpacing; node.paragraphIndent = e.paragraphIndent;
          node.textAlignHorizontal = e.alignment;
          node.textDecoration = e.underline ? 'UNDERLINE' : e.strikethrough ? 'STRIKETHROUGH' : 'NONE';
          node.textAutoResize = 'HEIGHT'; node.resize(e.width, e.height);
          if (e.wordSpacing || e.kerning === false || (e.features && Object.keys(e.features).length) || (e.underline && e.strikethrough)) warnings.add('Review word spacing, kerning, OpenType or combined decorations in Figma; these settings are retained as layer metadata.');
          node.setPluginData('fontshelfTypography', JSON.stringify({ fontName: e.fontName, axes: e.axes, features: e.features, wordSpacing: e.wordSpacing, kerning: e.kerning, underline: e.underline, strikethrough: e.strikethrough }));
        } else { node = api.createRectangle(); frame.appendChild(node); node.resize(e.width, e.height); node.cornerRadius = e.radius; }
        node.name = e.section + (e.role ? ' / ' + e.role : ' / Shape'); node.x = e.x; node.y = e.y; node.fills = paint(e.color);
      }
      x += layout.width + 80;
    }
    api.currentPage.selection = created; api.viewport.scrollAndZoomIntoView(created);
    return 'Imported ' + created.length + ' editable frames.' + (warnings.size ? '\n\n' + [...warnings].join('\n') : '\nCheck line breaks before final handoff; Figma and macOS use different text renderers.');
  } catch (error) { for (const node of created) { if (!node.removed) node.remove(); } throw error; }
}
if (typeof figma !== 'undefined') {
  figma.showUI(__html__, { width: 440, height: 440 });
  let busy = false;
  figma.ui.onmessage = async message => {
    if (!message || message.type !== 'import' || busy) return;
    busy = true;
    try { figma.ui.postMessage({ type: 'result', message: await importLayout(message.payload, figma) }); }
    catch (error) { figma.ui.postMessage({ type: 'result', message: 'Import failed; new frames removed. ' + error.message }); }
    finally { busy = false; }
  };
}
if (typeof module !== 'undefined') module.exports = { validate, importLayout };
