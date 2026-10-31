'use strict';
const fs = require('node:fs'), path = require('node:path'), http = require('node:http'), os = require('node:os'), assert = require('node:assert/strict'), crypto = require('node:crypto');
const pw = require('playwright');
const root = path.join(__dirname, '..'), lab = path.join(root, 'tools/premium-v2');
const output = process.env.SHOTS || path.join(os.tmpdir(), 'premium-v2-streaming'); fs.mkdirSync(output, { recursive: true });
const manifest = JSON.parse(fs.readFileSync(path.join(lab, 'streaming-assets.json')));
for (const a of Object.values(manifest.atlases)) {
  const b = fs.readFileSync(path.join(lab, a.file)); assert.equal(b.length, a.bytes); assert.equal(crypto.createHash('sha256').update(b).digest('hex'), a.sha256);
}
for (const p of Object.values(manifest.pieces)) {
  const a = manifest.atlases[p.atlas]; assert.ok(p.uv[0] >= 2 && p.uv[1] >= 2 && p.uv[0] + p.uv[2] + 2 <= a.width && p.uv[1] + p.uv[3] + 2 <= a.height);
  assert.deepEqual(p.uv.slice(2), p.box.slice(2));
}
const html = `<!doctype html><html><meta charset="utf-8"><title>Streaming parity laboratory</title><canvas id="a" width="768" height="1216"></canvas><canvas id="b" width="768" height="1216"></canvas><script src="../../takeover-holo.js"></script><script src="pilot.js"></script><script src="streaming.js"></script><script>
window.defaultConfig={tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',top:'none',bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',feet:'boots',feetc:'schwarz',coat:'samurai',aura:'none',eyefx:'none',scene:'holo',pose_profile:'guard'};
Promise.all(['pilot-assets.json','streaming-assets.json'].map(s=>fetch(s).then(r=>r.json()))).then(([old,split])=>{window.oldAssets=old;window.splitAssets=split;window.loader=TLPremiumV2Streaming.createLoader();document.body.dataset.ready='true'});
</script></html>`;
let slowActive = 0, slowPeak = 0, slowRequests = 0;
const server = http.createServer((req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (pathname.endsWith('/stream-test.html')) { res.setHeader('Content-Type', 'text/html'); res.end(html); return; }
  const file = path.resolve(root, '.' + decodeURIComponent(pathname));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  fs.readFile(file, (error, data) => { if (error) { res.writeHead(404); res.end(); return; } res.setHeader('Content-Type', ({ '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json', '.png': 'image/png' })[path.extname(file)] || 'application/octet-stream'); if (req.url.includes('slow=1')) { slowActive++; slowRequests++; slowPeak = Math.max(slowPeak, slowActive); setTimeout(() => { slowActive--; res.end(data); }, 40); } else res.end(data); });
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); const base = 'http://127.0.0.1:' + server.address().port;
  try {
    for (const engine of (process.env.BROWSER || 'chromium,webkit').split(',')) {
      const browser = await pw[engine].launch();
      try {
        const page = await browser.newPage(), errors = [], external = []; page.on('pageerror', error => errors.push(error.message));
        await page.route('**/*', route => { if (!route.request().url().startsWith(base)) { external.push(route.request().url()); return route.abort(); } return route.continue(); });
        await page.goto(base + '/tools/premium-v2/stream-test.html'); await page.waitForFunction(() => document.body.dataset.ready === 'true');
        const parity = await page.evaluate(async () => {
          const reports = [];
          for (const pose of ['cool', 'guard']) for (const coat of ['none', 'samurai']) for (const glove of ['schwarzgold', 'weiss']) for (const hair of ['afro', 'kurz_glatt']) for (const bottomc of ['schwarz', 'rot']) {
            const c = { ...defaultConfig, pose_profile: pose, coat, glove, hair, bottomc }, old = TLPremiumV2Pilot.resolve(c, oldAssets), split = TLPremiumV2Streaming.resolve(old, splitAssets);
            const [oldImages, images] = await Promise.all([TLPremiumV2Pilot.prepare(old, 'v2'), loader.prepare(split)]);
            TLPremiumV2Pilot.draw(a.getContext('2d'), old, oldImages, 'v2'); TLPremiumV2Streaming.draw(b.getContext('2d'), split, images);
            let max = 0, sum = 0, over2 = 0; const x = a.getContext('2d').getImageData(0, 0, 768, 1216).data, y = b.getContext('2d').getImageData(0, 0, 768, 1216).data;
            for (let i = 0; i < x.length; i++) { const d = Math.abs(x[i] - y[i]); max = Math.max(max, d); sum += d; if (d > 2) over2++; }
            const itemParity = {};
            for (const slot of ['coat', 'hands', 'hair', 'bottom', 'feet']) {
              TLPremiumV2Pilot.draw(a.getContext('2d'), old, oldImages, 'v2', slot); TLPremiumV2Streaming.draw(b.getContext('2d'), split, images, slot);
              const p = a.getContext('2d').getImageData(0, 0, 768, 1216).data, q = b.getContext('2d').getImageData(0, 0, 768, 1216).data; let delta = 0;
              for (let i = 0; i < p.length; i++) delta += Math.abs(p[i] - q[i]); itemParity[slot] = delta / p.length;
            }
            reports.push({ pose, coat, glove, hair, bottomc, max, mean: sum / x.length, over2, itemParity });
          }
          return reports;
        });
        assert.equal(parity.length, 32); assert.ok(parity.every(r => r.max === 0 && Object.values(r.itemParity).every(n => n === 0)), 'split atlas pixels exactly match old atlas and item filters');
        slowActive = 0; slowPeak = 0; slowRequests = 0;
        await page.evaluate(async () => {
          const api = TLPremiumV2Streaming, fresh = api.createLoader(), s = api.resolve(TLPremiumV2Pilot.resolve(defaultConfig, oldAssets), splitAssets);
          s.pieces.forEach(p => { p.src += '?slow=1'; });
          await Promise.all([fresh.prepare(s), fresh.prepare(s), fresh.prepare(s)]);
        });
        assert.equal(slowRequests, 7, 'server observes only one download per group'); assert.equal(slowPeak, 3, 'server observes at most three concurrent requests');
        const cache = await page.evaluate(async () => {
          const api = TLPremiumV2Streaming, small = api.createLoader({ maxBytes: 1024 * 1024, maxEntries: 2 }), old = TLPremiumV2Pilot.resolve(defaultConfig, oldAssets), s = api.resolve(old, splitAssets);
          await Promise.all([small.prepare(s), small.prepare(s), small.prepare(s)]);
          const first = small.stats(); for (const a of Object.values(splitAssets.atlases)) await small.get(a.file);
          const second = small.stats(); small.clear();
          const unsupported = await api.prepareOrFallback({ ids: ['not-existing'] }, splitAssets, small);
          const failedManifest = structuredClone(splitAssets); failedManifest.atlases.base.file = 'streaming-assets/not-existing.png';
          const failure = await api.prepareOrFallback(old, failedManifest, small);
          const recovered = await api.prepareOrFallback(old, splitAssets, small);
          return { first, second, cleared: small.stats(), unsupported: unsupported.renderer, failure: failure.renderer, recovered: recovered.renderer, flags: [api.approved, api.enabled, splitAssets.approved, splitAssets.enabled] };
        });
        assert.equal(cache.first.requests, 7, 'three concurrent prepares share seven network requests');
        assert.ok(cache.first.peakActive <= 3); assert.ok(cache.second.cachedDecodedBytes <= 1024 * 1024 && cache.second.cachedEntries <= 2 && cache.second.evictions > 0);
        assert.equal(cache.unsupported, 'svg'); assert.equal(cache.failure, 'svg'); assert.equal(cache.recovered, 'anime-draft'); assert.deepEqual(cache.flags, [false, false, false, false]);
        // Exact same URL retries after a failed request instead of retaining its rejected promise.
        let failOnce = true;
        await page.route('**/retry.png', route => { if (failOnce) { failOnce = false; return route.fulfill({ status: 404, body: '' }); } return route.fulfill({ contentType: 'image/png', body: fs.readFileSync(path.join(lab, 'streaming-assets/hair-afro.png')) }); });
        const retry = await page.evaluate(async () => { const x = TLPremiumV2Streaming.createLoader(); let failed = false; try { await x.get('retry.png'); } catch { failed = true; } const result = await x.get('retry.png'); return { failed, width: result.naturalWidth, stats: x.stats() }; });
        assert.equal(retry.failed, true); assert.ok(retry.width > 0); assert.equal(retry.stats.requests, 2);
        // Original 110 iterations / 10 warmups / one-pixel readback method.
        const warm = await page.evaluate(async () => {
          const out = {};
          for (const mode of ['v1', 'v2', 'streaming']) {
            const old = ['cool', 'guard'].map(pose_profile => TLPremiumV2Pilot.resolve({ ...defaultConfig, pose_profile }, oldAssets)), selections = mode === 'streaming' ? old.map(s => TLPremiumV2Streaming.resolve(s, splitAssets)) : old;
            const images = await Promise.all(selections.map(s => mode === 'streaming' ? loader.prepare(s) : TLPremiumV2Pilot.prepare(s, mode))), cv = document.createElement('canvas'); cv.width = 768; cv.height = 1216; const g = cv.getContext('2d'), ts = [];
            for (let i = 0; i < 110; i++) { const t = performance.now(); if (mode === 'streaming') TLPremiumV2Streaming.draw(g, selections[i % 2], images[i % 2]); else TLPremiumV2Pilot.draw(g, selections[i % 2], images[i % 2], mode); g.getImageData(0, 0, 1, 1); if (i >= 10) ts.push(performance.now() - t); }
            ts.sort((a, b) => a - b); out[mode] = { p50ms: ts[50], p95ms: ts[95] };
          } return out;
        });
        const cold = [];
        for (const mode of ['v1', 'v2', 'streaming']) for (let n = 0; n < 3; n++) {
          const context = await browser.newContext(), p = await context.newPage();
          await p.goto(base + '/tools/premium-v2/stream-test.html'); await p.waitForFunction(() => document.body.dataset.ready === 'true');
          cold.push(await p.evaluate(async mode => {
            const old = TLPremiumV2Pilot.resolve(defaultConfig, oldAssets), s = mode === 'streaming' ? TLPremiumV2Streaming.resolve(old, splitAssets) : old, start = performance.now();
            const images = mode === 'streaming' ? await loader.prepare(s) : await TLPremiumV2Pilot.prepare(s, mode); await Promise.all(Object.values(images).map(i => i.decode()));
            if (mode === 'streaming') TLPremiumV2Streaming.draw(a.getContext('2d'), s, images); else TLPremiumV2Pilot.draw(a.getContext('2d'), s, images, mode); a.getContext('2d').getImageData(0, 0, 1, 1);
            const imageURLs = new Set(Object.keys(images).map(src => new URL(src, location.href).href));
            return { mode, loadDecodeFirstDrawMs: performance.now() - start, imageRequests: imageURLs.size, imageEncodedBytes: performance.getEntriesByType('resource').filter(r => imageURLs.has(r.name)).reduce((n, r) => n + r.encodedBodySize, 0), decodedRGBABytes: Object.values(images).reduce((n, i) => n + i.naturalWidth * i.naturalHeight * 4, 0), loader: mode === 'streaming' ? loader.stats() : null };
          }, mode)); await context.close();
        }
        const reference = cold.find(r => r.mode === 'v1'), stream = cold.find(r => r.mode === 'streaming'); assert.ok(stream.imageEncodedBytes < reference.imageEncodedBytes, 'first outfit bytes improve versus V1'); assert.ok(stream.decodedRGBABytes < 11149312); assert.equal(stream.loader.peakActive, 3);
        assert.deepEqual(errors, []); assert.deepEqual(external, []);
        fs.writeFileSync(path.join(output, engine + '-streaming.json'), JSON.stringify({ engine, parity, serverConcurrency: { requests: slowRequests, peak: slowPeak }, cache, retry, warm, cold }, null, 2) + '\n');
        console.log('PASS ' + engine + ': 32 outfits and item pixel parity, concurrency/dedup/LRU/retry/full fallback; ' + JSON.stringify({ reference, stream, warm }));
      } finally { await browser.close(); }
    }
  } finally { await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
