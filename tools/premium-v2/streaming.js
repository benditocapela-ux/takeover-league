/* Draft authoring utility. Never imported by the production editor. */
(function () {
  'use strict';
  // One queue across loader instances: never more than three image requests.
  const queue = []; let active = 0, peakActive = 0;
  function pump() {
    while (active < 3 && queue.length) {
      const job = queue.shift(); active++; peakActive = Math.max(peakActive, active);
      Promise.resolve().then(job.run).then(job.resolve, job.reject).finally(() => { active--; pump(); });
    }
  }
  function schedule(run) { return new Promise((resolve, reject) => { queue.push({ run, resolve, reject }); pump(); }); }
  function resolve(selection, manifest) {
    if (!selection || !Array.isArray(selection.ids) || !manifest || !Array.isArray(manifest.canvas)) return null;
    const pieces = [];
    for (const id of selection.ids) {
      const p = manifest.pieces[id], a = p && manifest.atlases[p.atlas];
      if (!p || !a || !Array.isArray(p.uv) || !Array.isArray(p.box) || p.uv[2] !== p.box[2] || p.uv[3] !== p.box[3]) return null;
      pieces.push({ id, ...p, src: a.file });
    }
    return { pose: selection.pose, ids: selection.ids.slice(), pieces, canvas: manifest.canvas.slice() };
  }
  function createLoader(options) {
    const opts = options || {};
    const limit = (value, fallback, min, max) => Number.isFinite(Number(value)) ? Math.max(min, Math.min(max, Math.floor(Number(value)))) : fallback;
    const maxBytes = limit(opts.maxBytes ?? 12 * 1024 * 1024, 12 * 1024 * 1024, 0, 32 * 1024 * 1024);
    const maxEntries = limit(opts.maxEntries ?? 16, 16, 0, 64);
    const timeoutMs = limit(opts.timeoutMs ?? 15000, 15000, 10, 120000);
    const cache = new Map(), pending = new Map(); let bytes = 0, requests = 0, hits = 0, evictions = 0, failures = 0;
    function trim() {
      while (cache.size && (cache.size > maxEntries || bytes > maxBytes)) {
        const key = cache.keys().next().value; bytes -= cache.get(key).bytes; cache.delete(key); evictions++;
      }
    }
    function get(src) {
      // Manifest URLs stay on the current origin. No remote asset fetching.
      const url = new URL(src, location.href);
      if (url.origin !== location.origin || !['http:', 'https:'].includes(url.protocol)) return Promise.reject(Error('Nonlocal artwork URL'));
      const key = url.href;
      if (cache.has(key)) { const value = cache.get(key); cache.delete(key); cache.set(key, value); hits++; return Promise.resolve(value.image); }
      if (pending.has(key)) { hits++; return pending.get(key); }
      const promise = schedule(() => new Promise((accept, reject) => {
        requests++; const image = new Image(); let settled = false;
        const fail = error => { if (settled) return; settled = true; clearTimeout(timer); failures++; image.onload = null; image.onerror = null; image.src = ''; reject(error); };
        const timer = setTimeout(() => fail(Error('Artwork load timeout: ' + src)), timeoutMs);
        image.onload = async () => {
          try {
            await image.decode();
            if (settled) return;
            settled = true; clearTimeout(timer);
            const size = image.naturalWidth * image.naturalHeight * 4;
            if (size <= maxBytes && maxEntries > 0) { cache.set(key, { image, bytes: size }); bytes += size; trim(); }
            accept(image);
          } catch (error) { fail(error); }
        };
        image.onerror = () => fail(Error('Missing draft artwork: ' + src));
        image.src = key;
      }));
      pending.set(key, promise);
      // Remove both successes and errors; failed downloads can be retried.
      promise.then(() => pending.delete(key), () => pending.delete(key));
      return promise;
    }
    async function prepare(selection) {
      if (!selection) throw Error('Unsupported premium selection');
      const sources = [...new Set(selection.pieces.map(p => p.src))], images = {};
      await Promise.all(sources.map(async src => { images[src] = await get(src); }));
      return images;
    }
    function clear() { cache.clear(); bytes = 0; }
    function stats() { return { cachedEntries: cache.size, cachedDecodedBytes: bytes, maxEntries, maxBytes, pending: pending.size, requests, hits, evictions, failures, active, peakActive, queued: queue.length }; }
    return Object.freeze({ get, load: get, prepare, clear, stats });
  }
  function draw(ctx, selection, images, slot) {
    if (!selection) throw Error('Unsupported premium selection');
    // Validate complete set before touching output; caller can render full SVG.
    for (const p of selection.pieces) if (!images[p.src]) throw Error('Incomplete draft outfit');
    ctx.clearRect(0, 0, ...selection.canvas);
    for (const p of selection.pieces) {
      if (slot && p.slot !== slot && !(slot === 'coat' && p.slot.startsWith('coat'))) continue;
      ctx.drawImage(images[p.src], ...p.uv, ...p.box);
    }
  }
  async function prepareOrFallback(selection, manifest, loader) {
    const resolved = resolve(selection, manifest);
    if (!resolved) return { renderer: 'svg', reason: 'unsupported' };
    try { return { renderer: 'anime-draft', selection: resolved, images: await loader.prepare(resolved) }; }
    catch (error) { return { renderer: 'svg', reason: 'load-failed', error: error.message }; }
  }
  window.TLPremiumV2Streaming = Object.freeze({ resolve, createLoader, draw, prepareOrFallback, approved: false, enabled: false });
})();
