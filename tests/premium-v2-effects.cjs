'use strict';
const fs = require('node:fs'), path = require('node:path'), http = require('node:http'), os = require('node:os'), assert = require('node:assert/strict'), crypto = require('node:crypto'), vm = require('node:vm');
const pw = require('playwright'), root = path.join(__dirname, '..'), lab = 'tools/premium-v2/', output = process.env.SHOTS || path.join(root, 'docs/premium-v2/evidence'); fs.mkdirSync(output, { recursive: true });
const manifest = JSON.parse(fs.readFileSync(path.join(root, lab + 'effects.json'))), sha = file => crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n')).digest('hex');
assert.equal(sha(lab + 'effects.js'), manifest.module.sha256); assert.equal(sha('takeover-holo.js'), manifest.source.sha256);
const source = fs.readFileSync(path.join(root, 'takeover-holo.js'), 'utf8'), ctx = { window: {} }; vm.runInNewContext(source.replace('window.TLHolo=', 'window.__EFX=EFX;window.TLHolo='), ctx);
assert.deepEqual(JSON.parse(JSON.stringify(ctx.window.__EFX)), Object.fromEntries(manifest.keys.eyefx.filter(k => k !== 'none').map(k => [k, manifest.palettes[k]])));
for (const key of manifest.keys.aura.filter(k => k !== 'none')) for (const color of manifest.palettes[key]) assert.ok(source.includes(color), 'existing aura palette retained');
const html = `<!doctype html><html><meta charset="utf-8"><script src="../../takeover-holo.js"></script><script src="pilot.js"></script><script src="effects.js"></script><script>
(async()=>{window.referenceConfig={tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',top:'none',bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',feet:'boots',feetc:'schwarz',coat:'none',aura:'none',eyefx:'none',scene:'holo',pose_profile:'guard'};const a=await(await fetch('pilot-assets.json')).json(),s=TLPremiumV2Pilot.resolve(referenceConfig,a),images=await TLPremiumV2Pilot.prepare(s,'v2');window.reference=document.createElement('canvas');reference.width=768;reference.height=1216;TLPremiumV2Pilot.draw(reference.getContext('2d'),s,images,'v2');document.body.dataset.ready='true'})().catch(e=>{window.error=e.message;document.body.dataset.ready='error'});
</script></html>`;
const server = http.createServer((req, res) => { const p = new URL(req.url, 'http://localhost').pathname; if (p.endsWith('effects-test.html')) { res.setHeader('Content-Type', 'text/html'); res.end(html); return; } const file = path.resolve(root, '.' + decodeURIComponent(p)); if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; } fs.readFile(file, (e, b) => { if (e) { res.writeHead(404); res.end(); return; } res.setHeader('Content-Type', ({ '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png' })[path.extname(file)] || 'text/plain'); res.end(b); }); });
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); const base = 'http://127.0.0.1:' + server.address().port, reports = [];
  try {
    for (const engine of (process.env.BROWSER || 'chromium,webkit').split(',')) {
      const browser = await pw[engine].launch();
      try {
        const page = await browser.newPage(), errors = [], external = []; page.on('pageerror', e => errors.push(e.message));
        await page.route('**/*', route => { if (!route.request().url().startsWith(base)) { external.push(route.request().url()); return route.abort(); } return route.continue(); });
        await page.goto(base + '/' + lab + 'effects-test.html'); await page.waitForFunction(() => document.body.dataset.ready === 'true');
        const result = await page.evaluate(() => {
          const api = TLPremiumEffects, canvas = () => { const c = document.createElement('canvas'); c.width = 768; c.height = 1216; return c; }, a = canvas(), b = canvas(), g = a.getContext('2d'), h = b.getContext('2d');
          // Synchronize WebKit deferred canvas output before exact RGBA readback; see WEBKIT_READBACK.md.
          const equal = () => { a.toDataURL(); b.toDataURL(); const x = g.getImageData(0, 0, 768, 1216).data, y = h.getImageData(0, 0, 768, 1216).data; for (let i = 0; i < x.length; i++) if (x[i] !== y[i]) return false; return true; };
          let combinations = 0;
          for (const pose_profile of ['cool', 'guard']) for (const scene of api.keys.scene) for (const aura of api.keys.aura) {
            const c = { ...referenceConfig, pose_profile, scene, aura }; g.clearRect(0, 0, 768, 1216); h.clearRect(0, 0, 768, 1216); api.drawBack(g, c, 0); api.drawSlot(h, c, 'scene', 0); api.drawSlot(h, c, 'aura', 0); if (!equal()) throw Error('Back/slot mismatch: '+JSON.stringify(c)); combinations++;
          }
          const eyes = [];
          for (const eyefx of api.keys.eyefx.filter(k => k !== 'none')) {
            const c = { ...referenceConfig, eyefx }; g.clearRect(0, 0, 768, 1216); h.clearRect(0, 0, 768, 1216); api.drawEyes(g, c, 0); api.drawSlot(h, c, 'eyefx', 0); if (!equal()) throw Error('Eye/slot mismatch: '+eyefx);
            const pixels = g.getImageData(0, 0, 768, 1216).data; let visible = 0, outside = 0;
            for (let y = 0; y < 1216; y++) for (let x = 0; x < 768; x++) if (pixels[(y * 768 + x) * 4 + 3]) { visible++; if (y < 147 || y > 163 || !((x >= 345 && x <= 369) || (x >= 394 && x <= 418))) outside++; }
            eyes.push({ eyefx, visible, outside });
          }
          g.clearRect(0, 0, 768, 1216); h.clearRect(0, 0, 768, 1216); const reduced = { ...referenceConfig, aura: 'sakura', eyefx: 'stern', reducedMotion: true }; api.drawBack(g, reduced, 0); api.drawEyes(g, reduced, 0); api.drawBack(h, reduced, 45); api.drawEyes(h, reduced, 45); const reducedEqual = equal();
          const unsupported = [{ aura: 'new-aura' }, { scene: 'new-scene' }, { eyefx: 'new-eye' }, { pose_profile: 'jab' }].every(p => !api.supports({ ...referenceConfig, ...p }));
          g.globalAlpha = .42; g.lineWidth = 7; api.drawBack(g, referenceConfig); const statePreserved = g.globalAlpha === .42 && g.lineWidth === 7;
          return { combinations, eyes, reducedEqual, unsupported, statePreserved, flags: [api.approved, api.enabled], imageRequests: performance.getEntriesByType('resource').filter(r => r.name.includes('effects') && r.initiatorType === 'img').length };
        });
        assert.equal(result.combinations, 40); assert.ok(result.eyes.every(e => e.visible > 50 && e.outside === 0)); assert.equal(result.reducedEqual, true); assert.equal(result.unsupported, true); assert.equal(result.statePreserved, true); assert.deepEqual(result.flags, [false, false]); assert.equal(result.imageRequests, 0);
        // Contact sheets contain actual PR-81 Guard artwork behind registered effects.
        const contact = await page.evaluate(() => {
          const api = TLPremiumEffects, cv = document.createElement('canvas'); cv.width = 960; cv.height = 1302; const g = cv.getContext('2d'); g.fillStyle = '#101a2b'; g.fillRect(0, 0, cv.width, cv.height); g.fillStyle = '#f0d48f'; g.font = 'bold 18px system-ui'; g.fillText('Canvas-Effekte · echte Guard-Referenz · Entwürfe', 16, 30);
          const slots = ['scene', 'aura', 'eyefx']; for (let row = 0; row < slots.length; row++) { const slot = slots[row], values = api.keys[slot].filter(v => v !== 'none'); values.forEach((value, col) => { const c = { ...referenceConfig, [slot]: value }, render = document.createElement('canvas'); render.width = 768; render.height = 1216; const r = render.getContext('2d'); api.drawBack(r, c); r.drawImage(reference, 0, 0); api.drawEyes(r, c); const x = col * 240, y = 46 + row * 418; g.drawImage(render, x, y, 240, 380); g.fillStyle = '#f0e8d8'; g.font = '14px system-ui'; g.fillText(slot + ' · ' + value, x + 10, y + 402); }); } return cv.toDataURL().split(',')[1];
        });
        fs.writeFileSync(path.join(output, engine + '-effects-contact.png'), Buffer.from(contact, 'base64'));
        const eyeContact = await page.evaluate(() => {
          const api = TLPremiumEffects, cv = document.createElement('canvas'); cv.width = 1000; cv.height = 310; const g = cv.getContext('2d'); g.fillStyle = '#101a2b'; g.fillRect(0, 0, 1000, 310);
          api.keys.eyefx.filter(k => k !== 'none').forEach((eyefx, i) => { const c = document.createElement('canvas'); c.width = 768; c.height = 1216; const r = c.getContext('2d'); r.drawImage(reference, 0, 0); api.drawEyes(r, { ...referenceConfig, eyefx }); g.drawImage(c, 325, 125, 115, 105, i * 250, 20, 250, 228); g.fillStyle = '#efd08a'; g.font = '18px system-ui'; g.fillText(eyefx + ' · Entwurf', i * 250 + 12, 282); }); return cv.toDataURL().split(',')[1];
        }); fs.writeFileSync(path.join(output, engine + '-effects-eyes.png'), Buffer.from(eyeContact, 'base64'));
        assert.deepEqual(errors, []); assert.deepEqual(external, []); reports.push({ engine, passed: true, ...result }); console.log('PASS ' + engine + ': 40 scene/aura compositions, 4 registered eye effects, identical tile source, reduced motion, zero effect PNG requests.');
      } finally { await browser.close(); }
    }
  } finally { await new Promise(resolve => server.close(resolve)); }
  fs.writeFileSync(path.join(output, 'effects-tests.json'), JSON.stringify({ passed: true, approved: false, enabled: false, artisticStatus: 'Artistically pending', hashAlgorithm: 'sha256-canonical-text-lf-v1', sourceHashes: { [lab + 'effects.js']: sha(lab + 'effects.js'), [lab + 'effects.json']: sha(lab + 'effects.json'), 'takeover-holo.js': sha('takeover-holo.js') }, reports }, null, 2) + '\n');
})().catch(error => { console.error(error); process.exitCode = 1; });
