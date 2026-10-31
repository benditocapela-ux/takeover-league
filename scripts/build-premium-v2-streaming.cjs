'use strict';
// Lossless export only: same registered pixels, no new artwork or resampling.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const { createCanvas, loadImage } = require(process.env.CANVAS_MODULE || '@napi-rs/canvas');
const root = path.join(__dirname, '..'), lab = path.join(root, 'tools/premium-v2');
const source = JSON.parse(fs.readFileSync(path.join(lab, 'pilot-assets.json')));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const groups = {
  base: ['head', 'lower', 'feet', 'eyes'],
  'body-cool': ['body-cool'], 'body-guard': ['body-guard'],
  'coat-common': ['coat-back', 'coat-tail'],
  'coat-cool': ['coat-cool'], 'coat-guard': ['coat-guard'],
  'hair-afro': ['hair-afro'], 'hair-short': ['hair-short'],
  'bottom-black': ['bottom-black'], 'bottom-red': ['bottom-red'],
  'top-tank': ['top-tank'],
  'hands-cool-black': ['hands-blackgold'], 'hands-cool-white': ['hands-white'],
  'hands-guard-black': ['guard-black-0', 'guard-black-1'],
  'hands-guard-white': ['guard-white-0', 'guard-white-1']
};
function pack(parts, width) {
  let x = 2, y = 2, height = 0;
  const boxes = [];
  for (const part of parts) {
    if (x + part.width + 2 > width) { x = 2; y += height + 4; height = 0; }
    boxes.push([x, y, part.width, part.height]);
    x += part.width + 4; height = Math.max(height, part.height);
  }
  return { width, height: y + height + 2, boxes };
}
(async () => {
  const images = {};
  for (const [id, asset] of Object.entries(source.atlases)) images[id] = await loadImage(path.join(lab, 'assets', asset.file));
  const directory = path.join(lab, 'streaming-assets'); fs.mkdirSync(directory, { recursive: true });
  const output = { version: 1, approved: false, enabled: false, sourceManifestHashAlgorithm: 'sha256-canonical-text-lf-v1', sourceManifestSha256: sha(Buffer.from(fs.readFileSync(path.join(lab, 'pilot-assets.json'), 'utf8').replace(/\r\n/g, '\n'))), canvas: source.canvas, pieces: {}, atlases: {} };
  for (const [name, ids] of Object.entries(groups)) {
    const parts = ids.map(id => {
      const p = source.pieces[id], c = createCanvas(p.uv[2], p.uv[3]), g = c.getContext('2d');
      g.drawImage(images[p.atlas], ...p.uv, 0, 0, c.width, c.height);
      const data = g.getImageData(0, 0, c.width, c.height);
      let left = c.width, top = c.height, right = -1, bottom = -1;
      for (let y = 0; y < c.height; y++) for (let x = 0; x < c.width; x++) if (data.data[(y * c.width + x) * 4 + 3] !== 0) {
        left = Math.min(left, x); top = Math.min(top, y); right = Math.max(right, x); bottom = Math.max(bottom, y);
      }
      if (right < 0) throw Error('Unexpected empty component: ' + id);
      return { id, p, canvas: c, trim: [left, top, right - left + 1, bottom - top + 1], width: right - left + 1, height: bottom - top + 1 };
    });
    // Stable shelf packing chooses smallest decoded area; no power-of-two padding.
    const min = Math.max(...parts.map(p => p.width + 4));
    const candidates = [...new Set([min, ...[256, 384, 512, 640, 768, 1024].filter(w => w >= min)])].map(w => pack(parts, w));
    candidates.sort((a, b) => a.width * a.height - b.width * b.height || a.width - b.width);
    const layout = candidates[0], c = createCanvas(layout.width, layout.height), g = c.getContext('2d');
    parts.forEach((part, i) => {
      const [x, y, w, h] = layout.boxes[i], [tx, ty] = part.trim;
      // putImageData avoids a second filtered/premultiplied draw during export.
      g.putImageData(part.canvas.getContext('2d').getImageData(...part.trim), x, y);
      output.pieces[part.id] = { slot: part.p.slot, origin: part.p.origin, atlas: name, uv: [x, y, w, h], box: [part.p.box[0] + tx, part.p.box[1] + ty, w, h], sourceBox: part.p.box, sourceUv: part.p.uv, sourceAtlas: part.p.atlas };
    });
    const bytes = c.toBuffer('image/png'), file = name + '.png'; fs.writeFileSync(path.join(directory, file), bytes);
    output.atlases[name] = { file: 'streaming-assets/' + file, width: c.width, height: c.height, bytes: bytes.length, sha256: sha(bytes) };
  }
  fs.writeFileSync(path.join(lab, 'streaming-assets.json'), JSON.stringify(output, null, 2) + '\n');
  console.log(JSON.stringify({ groups: Object.keys(output.atlases).length, components: Object.keys(output.pieces).length, totalBytes: Object.values(output.atlases).reduce((n, a) => n + a.bytes, 0) }));
})().catch(error => { console.error(error); process.exitCode = 1; });
