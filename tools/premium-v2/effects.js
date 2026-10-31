/* Code-native premium effects draft. Deterministic, no timers, images or persistence. */
(function (root) {
  'use strict';
  const W = 768, H = 1216;
  const palette = Object.freeze({
    flamme: ['#ff6a1f', '#ffd23a'], blitz: ['#4fd8ff', '#bff4ff'],
    sakura: ['#ff9ad0', '#ffc2e2', '#d25a96'], schatten: ['#5a2bb0', '#14081f'],
    kristall: ['#9ff0ff', '#0b4a6e', '#ffffff', '#4fd8ff'],
    glut: ['#ff3b2f', '#3a0604', '#ffb03a', '#ffd23a'],
    stern: ['#ffe14f', '#6e4a00', '#fff8c8', '#ffffff'],
    mond: ['#c8c2ff', '#1c1450', '#ffffff', '#9b5cff']
  });
  const keys = Object.freeze({ aura: ['none', 'flamme', 'sakura', 'blitz', 'schatten'], eyefx: ['none', 'kristall', 'glut', 'stern', 'mond'], scene: ['holo', 'dojo', 'neon', 'arena'] });
  const eyeAnchors = Object.freeze([[357, 155], [406, 155]]);
  function config(c = {}) { return { aura: c.aura || 'none', eyefx: c.eyefx || 'none', scene: c.scene || 'holo', pose_profile: c.pose_profile || 'guard', reducedMotion: c.reducedMotion }; }
  function supports(input) { const c = config(input); return ['cool', 'guard'].includes(c.pose_profile) && Object.entries(keys).every(([key, list]) => list.includes(c[key])); }
  function phase(c, time) {
    const systemReduced = typeof root.matchMedia === 'function' && root.matchMedia('(prefers-reduced-motion: reduce)').matches;
    return c.reducedMotion || systemReduced || !Number.isFinite(time) ? 0 : Math.max(0, time % 120);
  }
  const rgb = hex => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
  const rgba = (hex, a) => 'rgba(' + [...rgb(hex), a].join(',') + ')';
  const random = i => { const x = Math.sin(i * 127.1 + 31.7) * 43758.5453; return x - Math.floor(x); };
  function halo(g, x, y, rx, ry, color, opacity) {
    g.save(); g.translate(x, y); g.scale(rx, ry); const r = g.createRadialGradient(0, 0, 0, 0, 0, 1);
    r.addColorStop(0, rgba(color, opacity)); r.addColorStop(.45, rgba(color, opacity * .45)); r.addColorStop(1, rgba(color, 0)); g.fillStyle = r; g.fillRect(-1, -1, 2, 2); g.restore();
  }
  function path(g, points) { g.beginPath(); points.forEach(([x, y], i) => g[i ? 'lineTo' : 'moveTo'](x, y)); }
  function line(g, points, color, width, alpha = 1) { g.save(); path(g, points); g.strokeStyle = color; g.lineWidth = width; g.globalAlpha = alpha; g.stroke(); g.restore(); }
  function floor(g, color) {
    const f = g.createLinearGradient(0, 910, 0, H); f.addColorStop(0, '#142238'); f.addColorStop(1, '#070d18'); g.fillStyle = f; g.fillRect(0, 910, W, H - 910);
    halo(g, 384, 1148, 330, 65, color, .12);
    g.save(); g.strokeStyle = rgba(color, .35); g.lineWidth = 1.2; g.beginPath(); g.ellipse(384, 1158, 285, 42, 0, 0, Math.PI * 2); g.stroke(); g.restore();
  }
  function drawScene(g, c) {
    const bg = g.createLinearGradient(0, 0, 0, H); bg.addColorStop(0, '#070e1a'); bg.addColorStop(.53, '#15263c'); bg.addColorStop(1, '#08101d'); g.fillStyle = bg; g.fillRect(0, 0, W, H);
    halo(g, 384, 410, 520, 600, '#476687', .22);
    if (c.scene === 'holo') {
      floor(g, '#d4ae62'); halo(g, 384, 1070, 270, 400, '#82b5dc', .06);
      g.save(); g.lineWidth = 1; g.strokeStyle = 'rgba(165,194,218,.09)';
      for (let i = -3; i <= 3; i++) line(g, [[384 + i * 60, 910], [384 + i * 175, H]], '#7695b3', .8, .12);
      for (const y of [955, 1005, 1080, 1180]) line(g, [[0, y], [W, y]], '#7695b3', .8, .1);
      g.setLineDash([12, 14]); g.beginPath(); g.ellipse(384, 1158, 225, 30, 0, 0, Math.PI * 2); g.strokeStyle = 'rgba(225,189,113,.4)'; g.stroke(); g.restore();
    } else if (c.scene === 'dojo') {
      // Existing warm wood/shoji palette translated into a dark training hall.
      const wood = '#8a5a32', paper = '#efe2c4'; halo(g, 384, 350, 460, 510, paper, .12);
      for (let col = 0; col < 4; col++) for (let row = 0; row < 5; row++) {
        const x = 36 + col * 178, y = 60 + row * 157, fill = g.createLinearGradient(x, y, x + 158, y + 140); fill.addColorStop(0, rgba(paper, .05)); fill.addColorStop(1, rgba(paper, .13)); g.fillStyle = fill; g.fillRect(x, y, 158, 140);
      }
      for (let x = 24; x < W; x += 178) line(g, [[x, 40], [x, 900]], wood, 10, .55);
      for (let y = 40; y < 910; y += 157) line(g, [[20, y], [W - 20, y]], wood, 7, .45);
      floor(g, '#caa96b');
      for (let i = 0; i < 7; i++) line(g, [[0, 925 + i * i * 7], [W, 925 + i * i * 7]], '#6b4224', 2, .5);
    } else if (c.scene === 'neon') {
      halo(g, 620, 360, 370, 550, '#ff3ea5', .19); halo(g, 90, 500, 330, 600, '#3ef0ff', .16);
      for (let i = 0; i < 10; i++) {
        const x = i * 85 - 18, y = 470 - random(i + 30) * 240, w = 62 + random(i + 5) * 25; g.fillStyle = '#0c1425'; g.fillRect(x, y, w, 930 - y);
        for (let j = 0; j < 6; j++) if (random(i * 11 + j) > .35) line(g, [[x + 11, y + 28 + j * 44], [x + w - 12, y + 28 + j * 44]], i % 2 ? '#ff3ea5' : '#3ef0ff', 2, .3);
      }
      floor(g, '#3ef0ff'); line(g, [[0, 948], [W, 948]], '#ff3ea5', 2, .4); line(g, [[0, 1080], [W, 1080]], '#3ef0ff', 1.4, .25);
    } else if (c.scene === 'arena') {
      for (const x of [70, 698]) {
        g.save(); const beam = g.createLinearGradient(x, 0, x, 950); beam.addColorStop(0, 'rgba(223,235,255,.24)'); beam.addColorStop(1, 'rgba(223,235,255,0)'); g.fillStyle = beam; path(g, [[x - 14, 15], [x + 14, 15], [x + 230, 950], [x - 230, 950]]); g.closePath(); g.fill(); g.restore(); halo(g, x, 24, 90, 40, '#ecf1ff', .6);
      }
      for (let i = 0; i < 80; i++) { g.fillStyle = rgba('#acc2e6', .06 + random(i + 41) * .1); g.beginPath(); g.arc(random(i + 80) * W, 570 + random(i + 90) * 200, 1.5 + random(i + 6) * 3, 0, Math.PI * 2); g.fill(); }
      floor(g, '#b7c7df');
      [['#e0263a', 700], ['#f4f4f6', 780], ['#2f6bff', 860]].forEach(([color, y]) => { line(g, [[0, y + 4], [W, y + 4]], '#02050b', 9, .8); line(g, [[0, y], [W, y]], color, 5, .55); });
      for (const x of [25, 743]) { const steel = g.createLinearGradient(x - 7, 0, x + 7, 0); steel.addColorStop(0, '#26364b'); steel.addColorStop(.45, '#b5c6d8'); steel.addColorStop(1, '#304154'); g.fillStyle = steel; g.fillRect(x - 7, 670, 14, 270); }
    }
    // Vignette keeps visual focus on the character, not the backdrop geometry.
    const edge = g.createRadialGradient(384, 530, 180, 384, 530, 850); edge.addColorStop(0, 'rgba(0,0,0,0)'); edge.addColorStop(1, 'rgba(0,0,0,.65)'); g.fillStyle = edge; g.fillRect(0, 0, W, H);
  }
  function drawAura(g, c, time) {
    if (c.aura === 'none') return;
    const p = palette[c.aura], t = phase(c, time); halo(g, 384, 605, 330, 570, p[0], c.aura === 'schatten' ? .2 : .13);
    g.save(); g.lineCap = 'round'; g.lineJoin = 'round';
    if (c.aura === 'flamme' || c.aura === 'schatten') {
      for (let side = -1; side <= 1; side += 2) for (let i = 0; i < 5; i++) {
        const x = 384 + side * (172 + i * 20), sway = Math.sin(t * .3 + i) * 9, y = 1120 - i * 70;
        const glow = g.createLinearGradient(0, y - 650, 0, y); glow.addColorStop(0, rgba(p[1], 0)); glow.addColorStop(.45, rgba(p[0], .12)); glow.addColorStop(1, rgba(p[1], .01));
        g.beginPath(); g.moveTo(x, y); g.bezierCurveTo(x - side * 70, y - 160, x + side * 45, y - 290, x + sway, y - 600); g.bezierCurveTo(x + side * 70, y - 350, x - side * 20, y - 180, x + side * 30, y); g.closePath(); g.fillStyle = glow; g.fill();
        g.beginPath(); g.moveTo(x, y - 15); g.bezierCurveTo(x - side * 25, y - 190, x + side * 50, y - 330, x + sway, y - 575); g.strokeStyle = rgba(p[0], .2); g.lineWidth = c.aura === 'flamme' ? 1.2 : 3; g.stroke();
      }
      for (let i = 0; i < 42; i++) { const side = i % 2 ? -1 : 1, x = 384 + side * (175 + random(i + 4) * 135), y = 100 + (random(i + 7) * 1010 - t * 8 + 1216) % 1010; g.fillStyle = rgba(c.aura === 'flamme' ? p[1] : '#b294e0', .2 + random(i + 8) * .4); g.beginPath(); g.ellipse(x, y, .8 + random(i) * 1.5, c.aura === 'flamme' ? 2.6 : 1.1, .2, 0, Math.PI * 2); g.fill(); }
    } else if (c.aura === 'blitz') {
      for (const [side, n] of [[-1, 0], [1, 1]]) for (let j = 0; j < 3; j++) {
        const y = 120 + j * 305 + n * 65, x = 384 + side * (220 + j * 9), flicker = .8 + Math.sin(t * .8 + j) * .07;
        const points = [[x, y], [x + side * 27, y + 70], [x - side * 8, y + 64], [x + side * 32, y + 165], [x + side * 5, y + 151], [x + side * 22, y + 240]];
        line(g, points, p[0], 13, .06 * flicker); line(g, points, p[0], 5, .17 * flicker); line(g, points, p[1], 1.3, .75 * flicker);
        line(g, [points[1], [x + side * 55, y + 100], [x + side * 50, y + 130]], p[0], .9, .4);
      }
    } else if (c.aura === 'sakura') {
      for (let i = 0; i < 24; i++) {
        const x = 384 + (i % 2 ? -1 : 1) * (175 + random(i + 10) * 135), y = 40 + (random(i + 20) * 1090 + t * 5) % 1090, size = 5 + random(i) * 5;
        g.save(); g.translate(x + Math.sin(t * .2 + i) * 4, y); g.rotate(random(i + 1) * Math.PI * 2 + t * .025); g.beginPath(); g.moveTo(0, -size); g.bezierCurveTo(size * .85, -size * .45, size * .6, size * .7, 0, size); g.bezierCurveTo(-size * .7, size * .6, -size * .85, -size * .5, 0, -size); g.fillStyle = rgba(p[1], .45 + random(i + 2) * .3); g.fill(); line(g, [[0, -size * .6], [0, size * .65]], p[2], .7, .45); g.restore();
      }
    }
    g.restore();
  }
  function drawEyes(g, input, time = 0) {
    const c = config(input); if (!supports(c) || c.eyefx === 'none') return false;
    const p = palette[c.eyefx], t = phase(c, time), pulse = .92 + Math.sin(t * .65) * .04;
    g.save();
    for (const [x, y] of eyeAnchors) {
      halo(g, x, y, 12, 8, p[3], .19 * pulse); g.save(); g.beginPath(); g.ellipse(x, y, 4.1, 4.8, 0, 0, Math.PI * 2); g.clip();
      const iris = g.createLinearGradient(x, y - 5, x, y + 5); iris.addColorStop(0, p[1]); iris.addColorStop(.5, p[0]); iris.addColorStop(1, p[2]); g.fillStyle = iris; g.fillRect(x - 5, y - 6, 10, 12);
      if (c.eyefx === 'kristall') { path(g, [[x, y - 3.5], [x + 2.6, y], [x, y + 3.5], [x - 2.6, y]]); g.closePath(); g.fillStyle = p[1]; g.fill(); line(g, [[x - 3.5, y + 1], [x + 3.5, y - 2]], p[2], .55, .8); }
      if (c.eyefx === 'glut') { g.fillStyle = p[1]; g.beginPath(); g.ellipse(x, y, 1.15, 3.8, 0, 0, Math.PI * 2); g.fill(); line(g, [[x - 2.5, y + 2], [x, y + 3], [x + 2.5, y + 1]], p[3], .8, .9); }
      if (c.eyefx === 'stern') { const points = []; for (let i = 0; i < 10; i++) { const angle = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 ? 1.35 : 3.5; points.push([x + Math.cos(angle) * r, y + Math.sin(angle) * r]); } path(g, points); g.closePath(); g.fillStyle = p[1]; g.fill(); }
      if (c.eyefx === 'mond') { g.fillStyle = p[1]; g.beginPath(); g.arc(x, y, 3.2, 0, Math.PI * 2); g.fill(); g.fillStyle = p[2]; g.beginPath(); g.arc(x - .9, y - .8, 2.9, .4, 5.9); g.bezierCurveTo(x - .1, y - 1, x - .1, y + 1.7, x - 2.5, y + 1.7); g.closePath(); g.fill(); }
      g.fillStyle = '#ffffff'; g.globalAlpha = .9; g.beginPath(); g.arc(x - 1.5, y - 2.3, .8, 0, Math.PI * 2); g.fill(); g.restore();
    }
    g.restore(); return true;
  }
  function drawBack(g, input, time = 0) {
    const c = config(input); if (!supports(c)) return false; g.save(); drawScene(g, c); drawAura(g, c, time); g.restore(); return true;
  }
  function drawSlot(g, input, slot, time = 0) {
    const c = config(input); if (!supports(c)) return false; g.save();
    if (slot === 'scene') drawScene(g, c);
    else if (slot === 'aura') drawAura(g, c, time);
    else if (slot === 'eyefx') { g.restore(); return drawEyes(g, c, time); }
    else { g.restore(); return false; }
    g.restore(); return true;
  }
  const api = Object.freeze({ approved: false, enabled: false, artisticStatus: 'Artistically pending', renderer: 'Canvas', keys, palette, eyeAnchors, supports, drawBack, drawEyes, drawSlot });
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.TLPremiumEffects = api;
})(typeof window === 'undefined' ? globalThis : window);
