'use strict';
const assert=require('node:assert/strict');const fs=require('node:fs');
const pages=fs.readdirSync('.').filter(f=>f.endsWith('.html')&&!/preview\.html$/.test(f));
for(const p of pages){
 const s=fs.readFileSync(p,'utf8');
 assert.match(s,/<html\s+lang="de-CH"/i,p+' must declare de-CH language');
 assert.match(s,/<meta\s+name="viewport"/i,p+' missing viewport');
 assert.match(s,/<main\b/i,p+' missing landmark');
 assert.match(s,/class="tl-screen-symbol" aria-hidden="true"/,p+' decorative emoji must be hidden from SR');
 assert.match(s,/class="tl-screen-ribbon" aria-label=/,p+' contextual screen label missing');
}
const guest=fs.readFileSync('guest.html','utf8');
assert.match(guest,/role="tablist" aria-label="Öffentliche Gastbereiche"/);
for(const name of ['overview','ranking','challenges','duels','history']){
 assert.ok(guest.includes(`aria-controls="page-${name}"`),name+' missing tab target');
 assert.ok(guest.includes(`id="page-${name}" role="tabpanel"`),name+' missing tabpanel role');
}
assert.match(guest,/setAttribute\('aria-selected'/);
const css=fs.readFileSync('takeover-redesign.css','utf8');
assert.match(css,/focus-visible/);assert.match(css,/min-height:44px/);
assert.match(css,/prefers-reduced-motion:reduce/);assert.match(css,/safe-area-inset-bottom/);
console.log('PASS: 18 de-CH semantic screen shells, safe decorative symbols and five accessible guest tabs');
