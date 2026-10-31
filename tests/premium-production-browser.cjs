'use strict';
const fs = require('node:fs'), path = require('node:path'), http = require('node:http'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const pw = require('playwright'), root = path.join(__dirname, '..'), lab = 'tools/premium-v2/';
const output = process.env.SHOTS || path.join(root, 'docs/premium-v2/evidence'); fs.mkdirSync(output, { recursive: true });
const digest = b => crypto.createHash('sha256').update(b).digest('hex');
const sourceHash = (file, bytes = fs.readFileSync(path.join(root, file))) => digest(/\.(?:[cm]?js|json|html?|css|csv|md|ya?ml|txt)$/i.test(file) ? Buffer.from(bytes.toString('utf8').replace(/\r\n/g, '\n')) : bytes);
const read = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const matrix = read('docs/premium-v2/coverage.json'), art = read(lab + 'production-art/manifest.json');
const fingerprintFiles = ['tests/premium-production-browser.cjs', 'takeover-holo.js', 'takeover-mein-boxer-items.js', lab + 'production.html', lab + 'production.js', lab + 'materials.js', lab + 'materials.json', lab + 'streaming.js', lab + 'streaming-assets.json', lab + 'pilot.js', lab + 'pilot-assets.json', lab + 'production-art/manifest.json'];
for (const file of ['headwear/headwear.js', 'headwear/manifest.json', 'hair-expansion/manifest.json', 'tops/tops.js', 'tops/manifest.json', 'wraps/manifest.json', 'effects.js', 'effects.json']) if (fs.existsSync(path.join(root, lab + file))) fingerprintFiles.push(lab + file);
const initialHashes = Object.fromEntries(fingerprintFiles.map(f => [f, sourceHash(f)])), served = new Map();
let imageActive = 0, imagePeak = 0;
const server = http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname), file = path.resolve(root, '.' + pathname);
  if (pathname === '/' + lab + 'production-bench-fixture.html') {
    res.setHeader('Content-Type', 'text/html');
    const optionalScripts = ['headwear/headwear.js', 'tops/tops.js', 'effects.js'].filter(f => fs.existsSync(path.join(root, lab + f))).map(f => '<script src="' + f + '"></script>').join('');
    res.end(`<!doctype html><html><meta charset="utf-8"><canvas width="768" height="1216"></canvas><script src="../../takeover-holo.js"></script><script src="pilot.js"></script><script src="streaming.js"></script><script src="materials.js"></script>${optionalScripts}<script src="production.js"></script><script>
    (async()=>{await TLPremiumProduction.init();const t=performance.now(),result=await TLPremiumProduction.prepare(TLPremiumProduction.defaults);if(result.renderer!=='anime-draft')throw Error('No default production draft');await Promise.all(Object.values(result.images).map(im=>im.decode()));const g=document.querySelector('canvas').getContext('2d');TLPremiumProduction.draw(g,result.selection,result.images);g.getImageData(0,0,1,1);const urls=new Set(Object.keys(result.images).map(src=>new URL(src,location.href).href));window.result={mode:'production-new-art',loadDecodeFirstDrawMs:performance.now()-t,imageRequests:urls.size,imageEncodedBytes:performance.getEntriesByType('resource').filter(r=>urls.has(r.name)).reduce((n,r)=>n+r.encodedBodySize,0),decodedRGBABytes:Object.values(result.images).reduce((n,im)=>n+im.naturalWidth*im.naturalHeight*4,0),loader:TLPremiumProduction.loader.stats(),materials:TLPremiumMaterials.stats()};document.body.dataset.ready='true'})().catch(e=>{document.body.dataset.ready='error';window.error=e.message})
    </script></html>`); return;
  }
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  fs.readFile(file, (error, bytes) => {
    if (error) { res.writeHead(404); res.end(); return; }
    const relative = path.relative(root, file).split(path.sep).join('/'), hash = sourceHash(relative, bytes);
    if (served.has(relative) && served.get(relative) !== hash) served.set(relative, 'CHANGED_DURING_TEST'); else served.set(relative, hash);
    res.setHeader('Content-Type', ({ '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png' })[path.extname(file)] || 'application/octet-stream');
    if (path.extname(file) === '.png') { imageActive++; imagePeak = Math.max(imagePeak, imageActive); res.once('finish', () => { imageActive--; }); res.end(bytes); } else res.end(bytes);
  });
});
const variantKey = r => [r.slot, String(r.value), r.color, r.state, r.pose].join('|');
function patchFor(row) {
  const p = { pose_profile: row.pose, coat: 'none' };
  switch (row.slot) {
    case 'body': p.tone = Number(row.value); break;
    case 'eyes': p.eye = row.value; break;
    case 'hair': p.hair = row.value; p.hc = row.color; break;
    case 'head': p.head = row.value; p.headc = row.color; p.hair = 'kurz_glatt'; break;
    case 'top': p.top = row.value; p.topc = row.color; p.hood = row.state === 'up'; break;
    case 'bottom': p.bottom = row.value; p.bottomc = row.color; break;
    case 'feet': p.feet = row.value; p.feetc = row.color; break;
    case 'glove': p.glove = row.value; break;
    case 'hands': p.hands = row.value; break;
    case 'coat': p.coat = row.value; break;
    case 'aura': p.aura = row.value; break;
    case 'eyefx': p.eyefx = row.value; break;
    case 'scene': p.scene = row.value; break;
    default: return null;
  }
  return p;
}
async function ready(page) { await page.waitForFunction(() => ['true', 'error'].includes(document.body.dataset.ready)); assert.equal(await page.locator('body').getAttribute('data-ready'), 'true'); }
async function set(page, patch) {
  await page.evaluate(async patch => { await productionSet({ ...TLPremiumProduction.defaults, ...patch }); }, patch); await ready(page);
}
async function saveContact(page, entries, file, crop = [0, 0, 768, 1216], columns = 4, width = 240) {
  const shots = [];
  for (const entry of entries) {
    await set(page, entry.patch);
    if (await page.locator('body').getAttribute('data-renderer') !== 'anime-draft') continue;
    shots.push({ label: entry.label, image: await page.locator('#after').evaluate(c => c.toDataURL()) });
  }
  if (!shots.length) return null;
  const png = await page.evaluate(async ({ shots, crop, columns, width }) => {
    const height = Math.ceil(width * crop[3] / crop[2]), cv = document.createElement('canvas'); cv.width = columns * width; cv.height = 46 + Math.ceil(shots.length / columns) * (height + 34);
    const g = cv.getContext('2d'); g.fillStyle = '#101a2b'; g.fillRect(0, 0, cv.width, cv.height); g.fillStyle = '#f2d28c'; g.font = 'bold 17px system-ui'; g.fillText('Tatsächliche Labor-Ausgaben · Entwürfe, nicht freigegeben', 14, 28);
    for (let i = 0; i < shots.length; i++) { const im = new Image(); im.src = shots[i].image; await im.decode(); const x = i % columns * width, y = 46 + Math.floor(i / columns) * (height + 34); g.fillStyle = '#1f3048'; g.fillRect(x + 3, y, width - 6, height); g.drawImage(im, ...crop, x, y, width, height); g.fillStyle = '#f2eadb'; g.font = '13px system-ui'; g.fillText(shots[i].label, x + 8, y + height + 21, width - 16); }
    return cv.toDataURL().split(',')[1];
  }, { shots, crop, columns, width });
  fs.writeFileSync(path.join(output, file), Buffer.from(png, 'base64')); return { file, examples: shots.length, crop };
}
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); const base = 'http://127.0.0.1:' + server.address().port;
  const engineReports = [];
  try {
    for (const engine of (process.env.BROWSER || 'chromium,webkit').split(',')) {
      const browser = await pw[engine].launch();
      try {
        const page = await browser.newPage({ viewport: { width: 1440, height: 1120 } }), errors = [], external = [];
        page.on('pageerror', error => errors.push(error.message)); page.on('console', message => { if(message.type()==='warning'||message.type()==='error') console.log(engine, message.type(), message.text()); });
        await page.route('**/*', route => { if (!route.request().url().startsWith(base)) { external.push(route.request().url()); return route.abort(); } return route.continue(); });
        await page.goto(base + '/' + lab + 'production.html'); await ready(page);
        assert.equal(await page.locator('body').getAttribute('data-renderer'), 'anime-draft');
        await page.screenshot({ path: path.join(output, engine + '-production-before-after.png'), fullPage: true });
        const candidates = matrix.filter(r => ['cool', 'guard'].includes(r.pose)).map(row => ({ row, patch: patchFor(row) })).filter(x => x.patch);
        const supported = await page.evaluate(cases => cases.filter(c => TLPremiumProduction.resolve({ ...TLPremiumProduction.defaults, ...c.patch })), candidates);
        const validated = [], validations = [];
        for (const { row, patch } of supported) {
          await set(page, patch);
          assert.equal(await page.locator('body').getAttribute('data-renderer'), 'anime-draft', variantKey(row));
          const r = await page.evaluate(() => {
            const result = productionResult, P = TLPremiumProduction, out = [], expected = document.createElement('canvas'); expected.width = 768; expected.height = 1216;
            P.draw(expected.getContext('2d'), result.selection, result.images);
            const hero = document.getElementById('after'), compare = (a, b) => { let max = 0, sum = 0; for (let i = 0; i < a.length; i++) { const d = Math.abs(a[i] - b[i]); max = Math.max(max, d); sum += d; } return { max, mean: sum / a.length }; };
            hero.toDataURL(); expected.toDataURL(); const heroMatch = compare(hero.getContext('2d').getImageData(0, 0, 768, 1216).data, expected.getContext('2d').getImageData(0, 0, 768, 1216).data); const mismatchImages = heroMatch.max ? [hero.toDataURL(), expected.toDataURL()] : null;
            for (const tile of document.querySelectorAll('.item')) {
              const slot = tile.dataset.slot, cv = tile.querySelector('canvas'), frame = P.itemFrame(result.selection, slot);
              if (!frame) { out.push({ slot, empty: true, valid: !cv && tile.querySelector('small').textContent === 'Ohne' }); continue; }
              if (!cv) { out.push({ slot, valid: false }); continue; }
              P.draw(expected.getContext('2d'), result.selection, result.images, slot);
              const crop = document.createElement('canvas'); crop.width = frame[2]; crop.height = frame[3]; crop.getContext('2d').drawImage(expected, ...frame, 0, 0, crop.width, crop.height);
              const match = compare(cv.getContext('2d').getImageData(0, 0, cv.width, cv.height).data, crop.getContext('2d').getImageData(0, 0, crop.width, crop.height).data);
              const badge = ['scene', 'aura', 'eyefx'].includes(slot) ? 'Canvas · Entwurf' : 'Anime · Entwurf';
              out.push({ slot, valid: cv.width === frame[2] && cv.height === frame[3] && match.max === 0 && tile.querySelector('small').textContent === badge, ...match }); crop.width = 0; crop.height = 0;
            }
            expected.width = 0; expected.height = 0; return { mismatchImages, config: result.selection.config, heroMatch, items: out, ids: result.selection.ids, images: P.loader.stats(), materials: TLPremiumMaterials.stats(), flags: [P.approved, P.enabled] };
          });
          for (const [field, value] of Object.entries(patch)) assert.equal(r.config[field], value, 'UI must apply the actually tested variant: ' + variantKey(row) + ' / ' + field);
          if(r.mismatchImages) console.log(JSON.stringify({variant:variantKey(row),items:r.items,images:r.images,materials:r.materials})); if(r.mismatchImages) r.mismatchImages.forEach((u,i)=>fs.writeFileSync(path.join(output, engine+'-mismatch-'+i+'.png'),Buffer.from(u.split(',')[1],'base64'))); assert.equal(r.heroMatch.max, 0, 'hero output matches resolved drawing: ' + variantKey(row) + ' ' + JSON.stringify(r.heroMatch)); assert.ok(r.items.every(i => i.valid), 'tile uses the actual rendered component: ' + variantKey(row));
          assert.ok(r.images.peakActive <= 3 && r.images.cachedDecodedBytes <= r.images.maxBytes && r.images.cachedEntries <= r.images.maxEntries); assert.ok(r.materials.bytes <= r.materials.maxBytes && r.materials.entries <= r.materials.maxEntries); assert.deepEqual(r.flags, [false, false]);
          validated.push({ slot: row.slot, value: row.value, color: row.color, state: row.state, pose: row.pose }); validations.push({ variant: variantKey(row), sources: r.ids, heroMaxDelta: r.heroMatch.max, itemMaxDelta: Math.max(0, ...r.items.map(i => i.max || 0)) });
        }
        const bodyMask = await page.evaluate(async () => {
          const P = TLPremiumProduction, layers = [];
          for (const coat of ['none', 'samurai']) { const r = await P.prepare({ ...P.defaults, pose_profile: 'guard', coat, top: 'none' }), c = document.createElement('canvas'); c.width = 768; c.height = 1216; P.draw(c.getContext('2d'), r.selection, r.images, 'body'); layers.push(c.getContext('2d').getImageData(0, 0, 768, 1216).data); }
          let sleeveSkinRemoved = 0, chestChanges = 0, headLowerChanges = 0;
          for (let y = 0; y < 1216; y++) for (let x = 0; x < 768; x++) { const i = (y * 768 + x) * 4, changed = layers[0][i] !== layers[1][i] || layers[0][i + 1] !== layers[1][i + 1] || layers[0][i + 2] !== layers[1][i + 2] || layers[0][i + 3] !== layers[1][i + 3]; if (y >= 230 && y <= 480 && (x <= 320 || x >= 455) && layers[0][i + 3] > 220 && layers[1][i + 3] === 0) sleeveSkinRemoved++;
            if (y >= 340 && y < 470 && x >= 350 && x < 420 && changed) chestChanges++;
            if ((y < 230 || y >= 550) && changed) headLowerChanges++;
          }
          return { sleeveSkinRemoved, chestChanges, headLowerChanges, scope: 'Registered sleeve mask removes hidden arm pixels and preserves chest/head/lower body. This is not artistic/anatomical approval.' };
        });
        assert.ok(bodyMask.sleeveSkinRemoved > 1000, 'Guard coat applies actual body occlusion'); assert.equal(bodyMask.chestChanges, 0); assert.equal(bodyMask.headLowerChanges, 0);
        const fallback = [];
        for (const patch of [{ head: 'hijab' }, { pose_profile: 'jab' }, { top: 'hoodie', hood: true }, { top: 'shirt', topc: 'schwarz', coat: 'none', pose_profile: 'cool' }, { top: 'shirt', topc: 'schwarz', coat: 'none', pose_profile: 'guard' }, { coat: 'basic', pose_profile: 'cool', top: 'none' }]) {
          await set(page, patch); const result = await page.evaluate(() => ({ renderer: document.body.dataset.renderer, heroPNG: !!document.querySelector('#hero canvas'), heroSVG: !!document.querySelector('#hero svg'), animeBadges: [...document.querySelectorAll('.item small')].filter(x => /Anime|Canvas/.test(x.textContent)).length }));
          assert.deepEqual(result, { renderer: 'svg', heroPNG: false, heroSVG: true, animeBadges: 0 }); fallback.push({ patch, ...result });
        }
        const wrappedTones = [];
        const wrapSkinSupported = await page.evaluate(() => TLPremiumMaterials.wrapSkin === true);
        for (const pose_profile of ['cool', 'guard']) for (let tone = 0; tone < 8; tone++) {
          const patch = { hands: 'wraps', tone, pose_profile, coat: 'none' };
          const supportedWrap = await page.evaluate(patch => !!TLPremiumProduction.resolve({ ...TLPremiumProduction.defaults, ...patch }), patch);
          assert.equal(supportedWrap, tone === 6 || wrapSkinSupported, 'wrap tone support follows the actual material capability');
          await set(page, patch); const renderer = await page.locator('body').getAttribute('data-renderer');
          assert.equal(renderer, supportedWrap ? 'anime-draft' : 'svg');
          if (supportedWrap) {
            const result = await page.evaluate(() => ({ tone: productionResult.selection.config.tone, ids: productionResult.selection.pieces.filter(p => p.slot === 'hands').map(p => p.id), badge: document.querySelector('.item[data-slot="hands"] small').textContent }));
            assert.equal(result.tone, tone); assert.equal(result.ids.length, 2); assert.ok(result.ids.every(id => id.startsWith('wrap-' + pose_profile))); assert.equal(result.badge, 'Anime · Entwurf');
          } else { assert.equal(await page.locator('#hero svg').count(), 1); assert.equal(await page.locator('#hero canvas').count(), 0); }
          wrappedTones.push({ pose: pose_profile, tone, renderer });
        }
        await page.evaluate(async () => { await Promise.all([productionSet({ ...TLPremiumProduction.defaults, hair: 'stachel', head: 'none', top: 'none', pose_profile: 'guard' }), productionSet({ glove: 'rot' }), productionSet({ hair: 'afro', glove: 'weiss', coat: 'none' })]); }); await ready(page);
        const raced = await page.evaluate(() => ({ config: productionConfig(), selected: productionResult.selection.config })); assert.equal(raced.selected.hair, 'afro'); assert.equal(raced.selected.glove, 'weiss'); assert.equal(raced.selected.coat, 'none');
        // Failed actual PNG must render a full SVG, not only return a fallback token.
        const failurePage = await browser.newPage(); await failurePage.route('**/production-art/coat-guard-v2.png', route => route.fulfill({ status: 404, body: '' }));
        await failurePage.goto(base + '/' + lab + 'production.html'); await ready(failurePage);
        assert.equal(await failurePage.locator('body').getAttribute('data-renderer'), 'svg'); assert.equal(await failurePage.locator('#hero svg').count(), 1); assert.equal(await failurePage.locator('#hero canvas').count(), 0); await failurePage.close();
        await set(page, {}); await page.setViewportSize({ width: 390, height: 844 }); assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)); await page.screenshot({ path: path.join(output, engine + '-production-mobile.png'), fullPage: true }); await page.setViewportSize({ width: 1440, height: 1120 });
        const poses = ['cool', 'guard'], contacts = [], forms = await page.evaluate(() => TLHolo.HAIR_KEYS.filter(hair => TLPremiumProduction.resolve({ ...TLPremiumProduction.defaults, hair })));
        const entries = (values, key, extra = {}) => poses.flatMap(pose => values.map(value => ({ label: pose + ' · ' + key + ' ' + value, patch: { pose_profile: pose, coat: 'none', [key]: value, ...extra } })));
        contacts.push(await saveContact(page, entries(forms, 'hair'), engine + '-production-hair-contact.png', [215, 30, 345, 300]));
        contacts.push(await saveContact(page, entries(['boxer', 'kurz', 'jogger', 'track'], 'bottom'), engine + '-production-bottom-contact.png', [135, 500, 510, 700]));
        contacts.push(await saveContact(page, entries(['boots', 'sneaker'], 'feet'), engine + '-production-feet-contact.png', [135, 800, 510, 400]));
        contacts.push(await saveContact(page, entries([0, 1, 2, 3, 4, 5, 6, 7], 'tone'), engine + '-production-skin-contact.png', [190, 65, 390, 520]));
        contacts.push(await saveContact(page, entries(Object.keys(read(lab + 'materials.json').sourcePalettes.eyes), 'eye'), engine + '-production-eyes-contact.png', [330, 140, 100, 45]));
        contacts.push(await saveContact(page, entries(Object.keys(read(lab + 'materials.json').sourcePalettes.hair), 'hc'), engine + '-production-hair-colors.png', [285, 30, 200, 210]));
        contacts.push(await saveContact(page, entries(['rot', 'weiss', 'schwarzgold', 'eisblau', 'glut'], 'glove'), engine + '-production-gloves-contact.png', [195, 130, 390, 340]));
        contacts.push(await saveContact(page, entries([0, 1, 2, 3, 4, 5, 6, 7], 'tone', { hands: 'wraps' }), engine + '-production-wraps-contact.png', [195, 130, 390, 340]));
        contacts.push(await saveContact(page, entries(['none', 'samurai', 'basic'], 'coat'), engine + '-production-coat-contact.png'));
        contacts.push(await saveContact(page, entries(['cap', 'band'], 'head', { hair: 'kurz_glatt' }), engine + '-production-headwear-contact.png', [215, 30, 345, 300]));
        contacts.push(await saveContact(page, entries(['tank', 'shirt'], 'top', { topc: 'schwarz', hood: false }), engine + '-production-tops-contact.png', [170, 170, 430, 450]));
        contacts.push(await saveContact(page, entries(['flamme', 'sakura', 'blitz', 'schatten'], 'aura'), engine + '-production-aura-contact.png'));
        contacts.push(await saveContact(page, entries(['holo', 'dojo', 'neon', 'arena'], 'scene'), engine + '-production-scene-contact.png'));
        contacts.push(await saveContact(page, entries(['kristall', 'glut', 'stern', 'mond'], 'eyefx'), engine + '-production-eyefx-contact.png', [325, 120, 115, 105]));
        await set(page, {});
        const detail = await page.locator('#after').evaluate(c => { const cv = document.createElement('canvas'); cv.width = 1000; cv.height = 1040; const g = cv.getContext('2d'); g.fillStyle = '#1f3048'; g.fillRect(0, 0, cv.width, cv.height); g.drawImage(c, 135, 140, 500, 520, 0, 0, 1000, 1040); return cv.toDataURL().split(',')[1]; }); fs.writeFileSync(path.join(output, engine + '-production-guard-detail-200.png'), Buffer.from(detail, 'base64'));
        const warm = await page.evaluate(async () => {
          const P = TLPremiumProduction, prepared = await Promise.all(['cool', 'guard'].map(pose_profile => P.prepare({ ...P.defaults, pose_profile }))), cv = document.createElement('canvas'); cv.width = 768; cv.height = 1216; const g = cv.getContext('2d'), times = [];
          for (let i = 0; i < 110; i++) { const r = prepared[i % 2], t = performance.now(); P.draw(g, r.selection, r.images); g.getImageData(0, 0, 1, 1); if (i >= 10) times.push(performance.now() - t); }
          times.sort((a, b) => a - b); return { mode: 'production-new-art', p50ms: times[50], p95ms: times[95], samples: 100, warmups: 10 };
        });
        const cold = [];
        for (const mode of ['v1', 'v2', 'production-new-art']) for (let n = 0; n < 3; n++) {
          const context = await browser.newContext(), benchmark = await context.newPage();
          await benchmark.goto(base + '/' + lab + (mode === 'production-new-art' ? 'production-bench-fixture.html' : 'bench.html?mode=' + mode)); await ready(benchmark); cold.push(await benchmark.evaluate(() => window.result)); await context.close();
        }
        assert.deepEqual(errors, []); assert.deepEqual(external, []); assert.ok(imagePeak <= 3, 'server sees at most three active image requests');
        engineReports.push({ engine, passed: true, validatedVariants: validated, validations, bodyMask, wrappedTones, fallback, failedPNGFullSVGFallback: true, latestSelectionWins: true, mobileOverflow: false, externalRequests: external, jsErrors: errors, maxServerImageConcurrency: imagePeak, contacts: contacts.filter(Boolean), benchmarks: { cold, warm, method: 'Same 3 fresh contexts and 110 draws minus 10 warmups, forced pixel readback; no artificial network delay. Production uses corrected artwork and material pipeline, so this is a system comparison; use streaming test for equal-art renderer comparison.' } });
        fs.writeFileSync(path.join(output, engine + '-production-tests.json'), JSON.stringify(engineReports.at(-1), null, 2) + '\n');
        console.log('PASS ' + engine + ': ' + validated.length + ' integrated variant/pose cells, exact item tiles, full SVG fallback, race, mobile, cache/concurrency; ' + contacts.filter(Boolean).length + ' contact sheets.');
      } finally { await browser.close(); }
    }
  } finally { await new Promise(resolve => server.close(resolve)); }
  for (const [file, hash] of Object.entries(initialHashes)) assert.equal(sourceHash(file), hash, 'Source changed during run: ' + file);
  for (const [file, hash] of served) assert.equal(sourceHash(file), hash, 'Asset changed during run: ' + file);
  const engines = engineReports.map(r => r.engine), common = engineReports[0].validatedVariants.filter(v => engineReports.every(r => r.validatedVariants.some(x => variantKey(x) === variantKey(v))));
  const result = { passed: true, approved: false, enabled: false, artisticStatus: 'Artistically pending', hashAlgorithm: 'sha256-canonical-text-lf-v1', hashNotes: 'UTF-8 source text normalizes CRLF to LF; PNG and other binaries hash exact raw bytes.', engines, validatedVariants: common, sourceHashes: { ...initialHashes, ...Object.fromEntries(served) }, engineReports: engineReports.map(r => ({ engine: r.engine, file: r.engine + '-production-tests.json', variants: r.validatedVariants.length, contactSheets: r.contacts })), caveats: ['No physical-device or artistic approval.', 'Per-variant coverage uses a baseline outfit, not every Cartesian combination.', 'Pixel equality checks component identity and thumbnail fidelity, not anatomy or taste.'] };
  fs.writeFileSync(path.join(output, 'production-tests.json'), JSON.stringify(result, null, 2) + '\n');
  console.log('PASS production evidence: ' + engines.join(',') + ', ' + common.length + ' common validated cells; immutable source fingerprints recorded.');
})().catch(error => { console.error(error); process.exitCode = 1; });







