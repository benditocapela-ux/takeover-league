'use strict';
const fs=require('node:fs');const assert=require('node:assert/strict');
const excluded=new Set(['challenges-v2-preview.html','duels-v2-preview.html','league2-preview.html']);
const pages=fs.readdirSync('.').filter(n=>n.endsWith('.html')&&!excluded.has(n)).sort();
assert.equal(pages.length,23,'all 23 app entrypoints (including guest.html, bewertung.html, stil-test.html, checkin.html, praesenz.html and wochenplan.html)');
const stylesheet=fs.readFileSync('takeover-redesign.css','utf8');
assert.match(stylesheet,/--gold:#f2c14e/);assert.match(stylesheet,/--ok:#5fb27f/);
for(const page of pages){const s=fs.readFileSync(page,'utf8');const n=page.slice(0,-5);
 assert.match(s,/takeover-redesign\.css/,'missing redesign stylesheet: '+page);
 assert.ok(s.includes(`data-tl-screen="${n}"`),'missing page-specific design marker: '+page);
 assert.match(s,/class="tl-screen-ribbon"/,'missing native screen hierarchy: '+page);
 assert.ok(stylesheet.includes(`data-tl-screen="${n}"`),'missing per-screen styling: '+page);
 assert.ok(!/Judy.*560 EXP|Vaarun.*420 EXP|Wiran.*385 EXP/.test(s),'demo figures in production page: '+page);
}
for(const page of excluded){assert.ok(fs.existsSync(page),'excluded preview left untouched');}
console.log(`PASS: ${pages.length} actual user screens integrated in Fight Night / Sport-Dashboard visual system`);
