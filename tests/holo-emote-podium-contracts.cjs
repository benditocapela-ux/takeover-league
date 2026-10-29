'use strict';
// Holo-Podium und Sprechblasen: rein visuelle Ergänzung, ohne neue Datenfelder oder RPCs.
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8');
const kg=read('takeover-kampfgeist.js'),perf=read('takeover-performance.js'),css=read('takeover-redesign.css');
const ctx={window:{}};vm.createContext(ctx);vm.runInContext(kg,ctx);const K=ctx.window.TLKG;
for(const [shape,txt] of [['cloud','Respekt!'],['jag','GG!'],['burst','Stark!']]){
 for(const size of [28,44,56,84]){
  const html=K.emoteHTML({shape,col:'#ffb020',txt},size);
  assert.match(html,/kg-emote kg-emote-(cloud|jag|burst)/);
  assert.match(html,/aria-label="(Respekt!|GG!|Stark!)"/);
  assert.match(html,/<svg[^>]*aria-hidden="true"/);
  assert.ok(html.includes('width:'+size+'px'),'size '+size);
  assert.ok(html.includes('stroke="#ffb020"'),'accent uses server-provided item design');
 }
}
const malicious=K.emoteHTML({shape:'other',col:'"><script>alert(1)</script>',txt:'<svg/onload=alert(1)>'},52);
assert.doesNotMatch(malicious,/<script>|<svg\/onload/,'emotes must be escaped');
assert.match(malicious,/&lt;svg\/onload=alert\(1\)&gt;/);
assert.match(malicious,/kg-emote-cloud/,'invalid shape uses fallback');
const ids=[K.emoteHTML({shape:'cloud',col:'#ffffff',txt:'GG'},40),K.emoteHTML({shape:'cloud',col:'#ffffff',txt:'GG'},40)]
 .map(s=>s.match(/id="(kge\d+)"/)[1]);
assert.notEqual(ids[0],ids[1],'SVG gradient IDs are unique');
const section=perf.slice(perf.indexOf('async function mountPodiumHolos()'),perf.indexOf('/* ---- Etappe 11: Die Top 3 als FUT-Karten',perf.indexOf('async function mountPodiumHolos()')));
assert.ok(section.length>1000,'podium enhancer exists');
assert.match(section,/await db\.auth\.getSession\(\)/);
assert.match(section,/if\(!session\.data\|\|!session\.data\.session\)return;/);
assert.match(section,/db\.rpc\('get_holo_looks',\{p_display_names:names\}\)/);
assert.match(section,/const pose=H\.normalize\(cfg\)\.pose_profile;/);
assert.match(section,/H\.svg\(cfg,\{pose,scene:'none',holo:false\}\)/);
assert.match(section,/if\(!cfg\|\|typeof cfg!=='object'/);
assert.match(section,/dataset\.tlHoloChecked/,'idempotence after re-render');
assert.doesNotMatch(section,/\.from\(|\.insert\(|\.update\(|\.delete\(|\.upsert\(/,'no direct table writes');
assert.match(perf,/run\(mountPodiumHolos\)/);
assert.match(css,/\.tl-podium-holo-on>\.tl-kg-face/);
assert.match(css,/\.tl-champion-holo-on>\.tl-kg-face/);
assert.match(css,/\.kg-tier \.kg-pv/);
assert.match(css,/\.kg-emote b\{/);
assert.doesNotMatch([section,kg].join('\n'),/sb_secret_|service_role/);
console.log('PASS: Holo-Podium und Sprechblasen – vorhandene serverseitig freigegebene Looks, Profil-Pose, sichere Emotes in allen Grössen, Shop/Kampfpfad-Vorschauen, keine Datenänderung');
