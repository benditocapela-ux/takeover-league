'use strict';
// Static/vm contracts for Etappe 20b: hochwertigere Item-Zeichnungen direkt im Holo-Renderer (Handschuhe, Hosen, Oberteile,
// Schuhe, Mäntel, Kopf), Kampfgeist-Handschuhe mit Volumen/Naht/Schnürung, Sprechblasen ohne Wort-Trennung, Holo-Shop mit Bildern.
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const js=fs.readFileSync('takeover-holo.js','utf8'),kg=fs.readFileSync('takeover-kampfgeist.js','utf8'),page=fs.readFileSync('mein-boxer.html','utf8'),css=fs.readFileSync('takeover-redesign.css','utf8');
const load=src=>{const c={window:{}};vm.createContext(c);vm.runInContext(src,c);return c.window};
const H=load(js).TLHolo,K=load(kg).TLKG;
// Jede Item-Variante hat eine eigene Detail-Ebene (keine fehlende, keine überzählige)
const keys=(name)=>{const m=js.match(new RegExp('const '+name+'=\\{([\\s\\S]*?)\\n\\};'));assert.ok(m,name);return [...m[1].matchAll(/^ ([a-z_]+):/gm)].map(x=>x[1]).sort()};
assert.deepEqual(keys('XTOP'),keys('TOPS'));assert.deepEqual(keys('XBOT'),keys('BOTTOMS'));assert.deepEqual(keys('XFEET'),keys('FEET'));
assert.deepEqual(keys('XCOAT'),keys('COATS'));assert.deepEqual(keys('XGLOVE'),Object.keys(H.GL).sort());
// Am echten Holo sichtbar: jede Variante zeichnet anders als vorher die Grundform allein
const base={hands:'gloves',glove:'rot',bottom:'boxer',top:'none',coat:'none',feet:'boots'};
const strip=s=>s.replace(/tlh\d+/g,'ID');
const variants=[['glove',Object.keys(H.GL)],['bottom',['boxer','kurz','jogger','track']],['top',['tank','shirt','hoodie','jacke']],['coat',['basic','samurai','neon','drache']],['feet',['boots','sneaker']],['head',['cap','band','hijab']]];
for(const [slot,list] of variants){
 const out=list.map(v=>strip(H.svg(Object.assign({},base,{[slot]:v}),{})));
 assert.equal(new Set(out).size,list.length,slot+': every variant renders differently');
}
assert.match(H.svg(base,{}),/>TAKEOVER<\/text>/,'boxing trunks carry the waistband print');
assert.match(H.svg(Object.assign({},base,{coat:'drache'}),{}),/#f6efe0/,'dragon robe has the fur collar');
assert.match(H.svg(Object.assign({},base,{glove:'eisblau'}),{}),/#4fd8ff" opacity="\.14"/,'ice gloves glow');
// Volumen: Verläufe für Haut, Kleidung und Handschuhe; eindeutige IDs je Zeichnung
const one=H.svg(Object.assign({},base,{top:'hoodie',coat:'samurai'}),{});
for(const id of ['sk','tc','bc','fc','co','gv','gc'])assert.match(one,new RegExp('id="tlh\\d+'+id+'"'),'gradient '+id);
const ids=[...one.matchAll(/id="([^"]+)"/g)].map(m=>m[1]);assert.equal(new Set(ids).size,ids.length,'unique ids');
assert.notEqual(H.svg({},{}).match(/id="(tlh\d+)i"/)[1],H.svg({},{}).match(/id="(tlh\d+)i"/)[1]);
// Feindliche Werte bleiben wirkungslos, keine DOM-/Netzwerkzugriffe im Renderer
const evil={glove:'"><script>',bottom:'</svg>',top:'x" onload="y',coat:'javascript:x',feet:'<img>',head:'"'};
assert.equal(strip(H.svg(evil,{})),strip(H.svg({},{})));
assert.doesNotMatch(js,/fetch\(|XMLHttpRequest|innerHTML|eval\(/);
// Kampfgeist: Handschuh mit Verlauf, Naht und Schnürung; IDs eindeutig
const g1=K.gloveSVG({base:'#d8282f',acc:'#ffffff',cuff:'#f6f0e4',pat:'flame'});
assert.match(g1,/radialGradient id="kgg\d+"/);assert.match(g1,/stroke-dasharray="2\.4 2"/);
const gids=[...g1.matchAll(/id="([^"]+)"/g)].map(m=>m[1]);assert.equal(new Set(gids).size,gids.length);
assert.doesNotMatch(K.gloveSVG({base:'"><script>',acc:'x',cuff:'y'}),/script/);
// Sprechblasen: Schrift nach dem längsten Wort, Tiefe, keine Trennung mitten im Wort
assert.match(kg,/const longest=Math\.max\(1,\.\.\.txt\.split\(\/\\s\+\|\(\?<=-\)\/\)/);
assert.match(K.emoteHTML({txt:'RESPEKT.',shape:'cloud',col:'#3ee08a'},84),/translate\(2\.4 3\.6\)/);
assert.match(css,/overflow-wrap:normal;word-break:keep-all/);
assert.doesNotMatch(K.emoteHTML({txt:'<b>x</b>',col:'red"'},84),/<b>x<\/b>|red"/);
// Holo-Shop: Belohnungen mit Bild, Name/Seltenheit untereinander, Preis bricht nicht um
assert.equal((page.match(/class="mb-shop-item-art mb-art-\$\{esc\(i\.slot\)\}"/g)||[]).length,2);
assert.match(css,/\.mb-li \.mb-li-txt\{display:flex;flex-direction:column/);
assert.match(css,/\.mb-li>\.mb-btn,[^{]*\{white-space:nowrap;flex:none\}/);
console.log('PASS: Etappe 20b – jede Item-Variante (Handschuhe, Hosen, Oberteile, Schuhe, Mäntel, Kopf) mit eigener Detail-Ebene direkt am Holo, Volumen-Verläufe mit eindeutigen IDs, feindliche Werte wirkungslos, Kampfgeist-Handschuhe mit Naht und Schnürung, Sprechblasen ohne Worttrennung, Holo-Shop mit Bildern');
