'use strict';
// Actual-file audit; no database access and no changes to the historical PR-81 matrix.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), zlib = require('node:zlib');
const root = path.join(__dirname, '..'), dir = path.join(root, 'docs/premium-v2'), lab = 'tools/premium-v2/';
const read = (file, fallback = null) => fs.existsSync(path.join(root, file)) ? JSON.parse(fs.readFileSync(path.join(root, file), 'utf8')) : fallback;
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const inventory = read('docs/premium-v2/inventory.json'), historical = read('docs/premium-v2/coverage.json');
if (!inventory || !historical || inventory.catalogue.length !== 58) throw Error('Missing or changed repository inventory; regenerate and review first');
const art = read(lab + 'production-art/manifest.json', { pieces: {} });
const split = read(lab + 'streaming-assets.json', { pieces: {}, atlases: {} });
const materials = read(lab + 'materials.json', { families: {}, masks: {} });
const headwear = read(lab + 'headwear/manifest.json', { pieces: {}, colors: [], poses: [] });
const reportFile = 'docs/premium-v2/evidence/production-tests.json', report = read(reportFile);
const checks = new Map(), issues = [];
function alphaPopulation(bytes) {
  const width = bytes.readUInt32BE(16), height = bytes.readUInt32BE(20), channels = bytes[25] === 6 ? 4 : 2;
  if (bytes[24] !== 8 || bytes[28] !== 0 || width * height > 16000000) return null;
  const compressed = []; let offset = 8;
  while (offset + 12 <= bytes.length) { const length = bytes.readUInt32BE(offset), type = bytes.toString('ascii', offset + 4, offset + 8); if (type === 'IDAT') compressed.push(bytes.subarray(offset + 8, offset + 8 + length)); offset += length + 12; }
  const raw = zlib.inflateSync(Buffer.concat(compressed)), stride = width * channels;
  if (raw.length !== (stride + 1) * height) return null;
  let previous = Buffer.alloc(stride), visible = 0, transparent = 0;
  for (let y = 0; y < height; y++) {
    const row = Buffer.alloc(stride), start = y * (stride + 1), filter = raw[start]; if (filter > 4) return null;
    for (let x = 0; x < stride; x++) {
      const left = x >= channels ? row[x - channels] : 0, up = previous[x], corner = x >= channels ? previous[x - channels] : 0;
      let predictor = 0;
      if (filter === 1) predictor = left;
      if (filter === 2) predictor = up;
      if (filter === 3) predictor = Math.floor((left + up) / 2);
      if (filter === 4) { const p = left + up - corner, a = Math.abs(p - left), b = Math.abs(p - up), c = Math.abs(p - corner); predictor = a <= b && a <= c ? left : b <= c ? up : corner; }
      row[x] = (raw[start + 1 + x] + predictor) & 255;
      if (x % channels === channels - 1) { if (row[x] > 0) visible++; else transparent++; }
    }
    previous = row;
  }
  return { visiblePixels: visible, transparentPixels: transparent };
}
function fileHash(file) {
  const absolute = path.resolve(root, file);
  if (!absolute.startsWith(root + path.sep) || !fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) return null;
  const bytes = fs.readFileSync(absolute);
  return digest(/\.(?:[cm]?js|json|html?|css|csv|md|ya?ml|txt)$/i.test(file) ? Buffer.from(bytes.toString('utf8').replace(/\r\n/g, '\n')) : bytes);
}
function image(file, expected, registration) {
  const cacheKey = file + ':' + expected + ':' + JSON.stringify(registration?.uv || null);
  if (checks.has(cacheKey)) return checks.get(cacheKey);
  let value = null;
  const actual = fileHash(file);
  if (actual && actual === expected) {
    const b = fs.readFileSync(path.join(root, file));
    if (b.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
      const width = b.readUInt32BE(16), height = b.readUInt32BE(20), colorType = b[25];
      const uv = registration && registration.uv;
      let alpha; try { alpha = [4, 6].includes(colorType) && alphaPopulation(b); } catch { alpha = null; }
      if (alpha && alpha.visiblePixels > 0 && (!uv || uv.length === 4 && uv[0] >= 0 && uv[1] >= 0 && uv[2] > 0 && uv[3] > 0 && uv[0] + uv[2] <= width && uv[1] + uv[3] <= height)) value = { file, sha256: actual, width, height, alphaChannel: true, ...alpha };
    }
  }
  if (!value) issues.push({ file, issue: actual ? 'Hash/PNG/registration mismatch' : 'Missing source file' });
  checks.set(cacheKey, value); return value;
}
function piece(id) {
  const p = art.pieces[id];
  if (p) return image(lab + p.src, p.sha256, p);
  const s = split.pieces[id], a = s && split.atlases[s.atlas];
  return a ? image(lab + a.file, a.sha256, s) : null;
}
function pieces(ids) { const found = ids.map(piece); return found.every(Boolean) ? found : []; }
function masks(ids) {
  return ids.every(id => {
    const m = materials.masks[id]; return m && image(lab + m.file, m.sha256);
  });
}
const has = (family, key, pose) => {
  const f = materials.families[family]; return !!f && (!f.poses || f.poses.includes(pose)) && Array.isArray(f.keys) && f.keys.map(String).includes(String(key));
};
const cloth = (slot, value, color, pose) => {
  const direct = materials.families[slot], common = materials.families.clothing;
  if (direct && has(slot, color, pose) && (!direct.forms || direct.forms.includes(value))) return true;
  if (!common || !has('clothing', color, pose) || common.slots && !common.slots.includes(slot)) return false;
  if (!common.forms) return true;
  return Array.isArray(common.forms) ? common.forms.includes(value) : !!common.forms[slot]?.includes(value);
};
function available(row) {
  const { slot, value, color, pose } = row;
  if (!['cool', 'guard'].includes(pose)) return [];
  if (slot === 'body') {
    const ids = ['head', 'lower', 'body-' + pose, 'eyes'];
    return value === '6' || has('skin', value, pose) && masks(ids) ? pieces(ids) : [];
  }
  if (slot === 'eyes') return value === 'braun' || has('eyes', value, pose) && masks(['eyes']) ? pieces(['eyes']) : [];
  if (slot === 'hair') {
    // Bald is a removal state backed by the existing complete head, not eight new PNGs.
    if (value === 'glatze') return pieces(['head']);
    const id = value === 'kurz_glatt' ? 'hair-short' : 'hair-' + value;
    // Every additional form still requires a real registered PNG; a palette alone is not a hairstyle.
    return color === 'schwarz' || has('hair', color, pose) ? pieces([id]) : [];
  }
  if (slot === 'head') {
    const h = headwear.pieces[value];
    if (!h || !headwear.colors.includes(color) || !headwear.poses.includes(pose)) return [];
    const file = image(lab + h.src, h.sha256, h); return file ? [file] : [];
  }
  if (slot === 'bottom') {
    if (value === 'boxer' && cloth(slot, value, color, pose)) return pieces(['bottom-black']);
    if (value === 'boxer' && ['schwarz', 'rot'].includes(color)) return pieces(['bottom-' + (color === 'rot' ? 'red' : 'black')]);
    const id = value === 'boxer' ? 'bottom-black' : 'bottom-' + value;
    return color === 'schwarz' || cloth(slot, value, color, pose) ? pieces([id]) : [];
  }
  if (slot === 'feet') return color === 'schwarz' || cloth(slot, value, color, pose) ? pieces([value === 'boots' ? 'feet' : 'feet-' + value]) : [];
  if (slot === 'coat' && value === 'samurai') {
    if (pose === 'guard' && piece('coat-guard-v2')) return pieces(['coat-back', 'coat-guard-v2']);
    return pieces(['coat-back', 'coat-tail', 'coat-' + pose]);
  }
  if (slot === 'glove') {
    if (pose === 'guard' && piece('hands-master-0') && piece('hands-master-1')) {
      if (value === 'schwarzgold' || has('gloves', value, pose) || has('glove', value, pose)) return pieces(['hands-master-0', 'hands-master-1']);
    }
    if (has('gloves', value, pose) || has('glove', value, pose)) return pieces(pose === 'cool' ? ['hands-blackgold'] : ['hands-master-0', 'hands-master-1']);
    if (['schwarzgold', 'weiss'].includes(value)) return pieces(pose === 'cool' ? ['hands-' + (value === 'weiss' ? 'white' : 'blackgold')] : ['guard-' + (value === 'weiss' ? 'white' : 'black') + '-0', 'guard-' + (value === 'weiss' ? 'white' : 'black') + '-1']);
    return [];
  }
  if (slot === 'top' && value === 'tank' && color === 'schwarz' && pose === 'cool') return pieces(['top-tank']);
  return [];
}
const key = r => [r.slot, String(r.value), r.color || 'fixed', r.state || 'default', r.pose].join('|');
const tested = new Set((report?.validatedVariants || []).map(key));
const evidenceHashes = report?.sourceHashes || {};
const requiredCode = [lab + 'production.js', lab + 'materials.js', lab + 'materials.json', lab + 'streaming.js', lab + 'streaming-assets.json', lab + 'production-art/manifest.json'];
if (Object.keys(headwear.pieces).length) requiredCode.push(lab + 'headwear/headwear.js', lab + 'headwear/manifest.json');
const evidenceValid = !!report && report.passed === true && report.hashAlgorithm === 'sha256-canonical-text-lf-v1' && ['chromium', 'webkit'].every(e => report.engines?.includes(e)) && Object.keys(evidenceHashes).length > 0 && Object.entries(evidenceHashes).every(([file, hash]) => fileHash(file) === hash) && requiredCode.every(file => evidenceHashes[file] && fileHash(file) === evidenceHashes[file]);
const uniqueFiles = list => [...new Map(list.map(a => [a.file, a])).values()];
const matrix = historical.map(old => {
  const files = uniqueFiles(available(old)), exists = files.length > 0;
  const validated = exists && evidenceValid && tested.has(key(old)) && files.every(a => evidenceHashes[a.file] === a.sha256);
  return {
    slot: old.slot, value: old.value, color: old.color, state: old.state, pose: old.pose,
    availability: exists ? 'Artwork draft' : 'SVG only',
    technicalStatus: validated ? 'Technically validated' : 'Not validated',
    artisticStatus: exists ? 'Artistically pending' : 'Not applicable',
    approved: false, enabled: false, integratedAndTested: validated,
    newlySupported: validated && old.status === 'svg-only',
    previousStatus: old.status, sourceFiles: files.map(a => a.file), sourceHashes: Object.fromEntries(files.map(a => [a.file, a.sha256])),
    evidence: validated ? reportFile : '', reuse: old.reuse,
    caveat: exists ? 'Artwork availability does not imply complete-outfit compatibility or artistic approval. Only tested configurations count as technically integrated.' : 'No verified premium source for this item/colour/pose. Keep full SVG fallback.'
  };
});
const itemRows = inventory.catalogue.map(item => {
  const rows = matrix.filter(r => r.slot === item.slot && r.value === item.value), artwork = rows.filter(r => r.availability === 'Artwork draft'), technical = rows.filter(r => r.integratedAndTested);
  const variants = list => new Set(list.map(r => [r.value, r.color, r.state].join('|'))).size;
  return {
    key: item.key, name: item.name, slot: item.slot, value: item.value,
    totalVariantKeys: variants(rows), totalPoseCells: rows.length,
    artworkVariantKeys: variants(artwork), artworkPoseCells: artwork.length,
    technicallyValidatedVariantKeys: variants(technical), technicallyValidatedPoseCells: technical.length,
    newTechnicallySupportedPoseCells: technical.filter(r => r.newlySupported).length,
    availability: artwork.length ? 'Artwork draft' : 'SVG only',
    technicalStatus: technical.length ? 'Technically validated' : 'Not validated',
    artisticStatus: artwork.length ? 'Artistically pending' : 'Not applicable',
    approved: false, supportedPoses: [...new Set(technical.map(r => r.pose))],
    artworkPoses: [...new Set(artwork.map(r => r.pose))], sourceFiles: [...new Set(artwork.flatMap(r => r.sourceFiles))],
    note: item.slot === 'hair' && item.value === 'glatze' ? 'Bald uses the existing complete head and removes the hair layer. Eight allowed hair-colour keys have identical output; they are not eight new artworks.' : ['pose', 'scene', 'aura', 'eyefx'].includes(item.slot) ? 'Existing procedural/SVG catalogue entry; not a new independently authored PNG. Pose items are metadata.' : technical.length ? 'Only the reported variant/pose cells were browser-tested; full family and artist approval remain separate.' : artwork.length ? 'Files exist; no current matching dual-browser production evidence for this item.' : 'No verified premium artwork in this production package.'
  };
});
const technical = matrix.filter(r => r.integratedAndTested), newRows = technical.filter(r => r.newlySupported), artwork = matrix.filter(r => r.availability === 'Artwork draft');
const unique = list => new Set(list.map(r => [r.slot, r.value, r.color, r.state].join('|'))).size;
const summary = {
  catalogueEntries: itemRows.length, matrixRows: matrix.length, catalogueItemsWithArtwork: itemRows.filter(i => i.artworkPoseCells > 0).length,
  catalogueItemsTechnicallyValidated: itemRows.filter(i => i.technicallyValidatedPoseCells > 0).length,
  artworkVariantKeys: unique(artwork), artworkPoseCells: artwork.length,
  technicallyValidatedVariantKeys: unique(technical), technicallyValidatedPoseCells: technical.length,
  newlySupportedVariantKeys: unique(newRows), newlySupportedPoseCells: newRows.length,
  approvedItems: 0, hashAlgorithm: 'sha256-canonical-text-lf-v1', evidenceValid, evidenceReport: report ? reportFile : null,
  countsIncludeNonShopBodyEyesWraps: true,
  note: 'Variant keys count slot/value/colour/state once, independently of pose; pose cells count each supported pose. Neither count is a Cartesian full-outfit total.'
};
const csvCols = ['slot', 'value', 'color', 'state', 'pose', 'availability', 'technicalStatus', 'artisticStatus', 'integratedAndTested', 'newlySupported', 'previousStatus', 'sourceFiles', 'evidence'];
const csv = [csvCols.join(','), ...matrix.map(r => csvCols.map(k => '"' + String(Array.isArray(r[k]) ? r[k].join(';') : r[k]).replaceAll('"', '""') + '"').join(','))].join('\n') + '\n';
fs.writeFileSync(path.join(dir, 'production-coverage.json'), JSON.stringify({ summary, issues, matrix }, null, 2) + '\n');
fs.writeFileSync(path.join(dir, 'production-coverage.csv'), csv);
fs.writeFileSync(path.join(dir, 'production-progress.json'), JSON.stringify({ summary, entries: itemRows }, null, 2) + '\n');
const md = [
  '# Premium-Produktion: überprüfbarer Stand aller 58 Katalogeinträge', '',
  'Automatisch aus vorhandenem Inventar, tatsächlichen PNG-Dateien, Registrierungen, SHA-256 und aktuellem Browser-Testbericht erzeugt. Keine Live-Datenbankabfrage. Der historische PR-81-Stand bleibt in `coverage.csv`; die aktuelle Produktionsmatrix steht in `production-coverage.csv` und `production-coverage.json`.', '',
  `**${summary.catalogueItemsWithArtwork}/58 Katalogeinträge mit nachgewiesenen Grafikquellen; ${summary.catalogueItemsTechnicallyValidated}/58 mit aktueller technischer Testabdeckung; 0 freigegeben.**`, '',
  `Gesamtmatrix: ${summary.matrixRows} Zeilen. Grafikquellen für ${summary.artworkVariantKeys} unterschiedliche Varianten-Schlüssel bzw. ${summary.artworkPoseCells} Posezellen. Technisch integriert und geprüft: ${summary.technicallyValidatedVariantKeys} Varianten-Schlüssel / ${summary.technicallyValidatedPoseCells} Posezellen. Gegenüber dem historischen SVG-only-Stand neu: ${summary.newlySupportedVariantKeys} Varianten-Schlüssel / ${summary.newlySupportedPoseCells} Posezellen. Haut- und Augenfarben sind zusätzlich enthalten, aber keine neuen Shop-Items.`, '',
  '**Zählweise:** Varianten-Schlüssel = Slot, Itemwert, Farbe und Zustand; jede Pose wird zusätzlich als Posezelle gezählt. Das ist keine Anzahl aller kombinierbaren Outfits und keine Anzahl neuer PNGs. Ein Teil mit zwei Posen zählt nur einmal als Varianten-Schlüssel.', '',
  `Technische Evidenz: ${evidenceValid ? 'aktueller, hashgebundener Chromium-/WebKit-Bericht vorhanden' : 'noch kein vollständiger aktueller, hashgebundener Chromium-/WebKit-Bericht; technische Freigabe wird deshalb nicht behauptet'}.`, '',
  'Status getrennt: `SVG only` = keine verifizierte passende Grafik; `Artwork draft` = Datei und Registrierung vorhanden; `Technically validated` = passende Variante im aktuellen Bericht beider Engines und gültige Quellhashes; `Artistically pending` = persönliche Designabnahme offen. `Approved` wird durch dieses Skript niemals gesetzt. Auch ein technisch geprüfter Entwurf bleibt deaktiviert.', '',
  '| Item-Key | Name | Grafikvarianten / vorhanden | Technisch geprüft | geprüfte Posen | Status |',
  '|---|---|---:|---:|---|---|',
  ...itemRows.map(i => `| ${i.key} | ${i.name.replaceAll('|', '/')} | ${i.artworkVariantKeys}/${i.totalVariantKeys} | ${i.technicallyValidatedVariantKeys}/${i.totalVariantKeys} | ${i.supportedPoses.join(', ') || '–'} | ${i.availability}; ${i.technicalStatus}; ${i.artisticStatus} |`), '',
  'Posen, Szenen und Effekte behalten die vorhandene prozedurale/SVG-Darstellung, solange keine tatsächlich integrierte Premium-Familie nachgewiesen ist. Ein Guard-Pilot macht nicht sämtliche sechs Pose-Items zu fertigen Illustrationen.', '',
  'Reproduktion: `node scripts/inventory-premium-production.cjs`. Der technische Bericht liegt unter `docs/premium-v2/evidence/production-tests.json`; er muss `passed:true`, beide Engines, `validatedVariants` und passende `sourceHashes` enthalten. Hashverfahren `sha256-canonical-text-lf-v1`: UTF-8-Text normalisiert CRLF zu LF, PNG-/Binärdateien verwenden unveränderte Bytes. Damit lassen sich Windows- und Linux-Checkouts vergleichen. Fehlender oder veralteter Bericht fällt automatisch auf Entwurfsstatus zurück. Noch nicht kompatible vollständige Outfits müssen im Labor und im normalen Editor vollständig SVG bleiben.', '',
  issues.length ? `**Quellprobleme:** ${issues.length} Datei-/Hash-/Registrierungsfehler wurden nicht als vorhandene Grafik gezählt; Details in production-coverage.json.` : 'Alle gezählten Quellbilder haben passende PNG-Abmessungen, Alphakanal und SHA-256. Dieser Dateicheck ersetzt keine Sichtprüfung von Anatomie, Stoff, Verdeckung oder Materialien.', ''
].join('\n');
fs.writeFileSync(path.join(dir, 'PRODUCTION_PROGRESS.md'), md);
console.log(JSON.stringify(summary));
module.exports = { summary, matrix, entries: itemRows };
