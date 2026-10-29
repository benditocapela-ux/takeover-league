'use strict';
// Static contracts for Etappe 17b: überall öffentliche Kartenwerte (beste Karte = 92) – ausser auf der eigenen Bewertungsseite.
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const js=read('takeover-performance.js'),bew=read('bewertung.html'),holo=read('mein-boxer.html'),karten=read('karten.html');
// Studio-Kachel: nur der öffentliche Wert, keine Klammer
const studio=js.slice(js.indexOf('async function mountStudio'),js.indexOf('async function mountDuels'));
assert.match(studio,/const cs=pubOf\(r\.current\.summary\)\|\|r\.current\.summary/);assert.doesNotMatch(studio,/tlp-pub/);
// Karten-Vorschauen (Holo, Kartendesigns): öffentlich
assert.match(holo,/r=raw\?\(P\.pubOf\(raw\)\|\|raw\):null/);assert.match(karten,/r=raw\?\(P\.pubOf\(raw\)\|\|raw\):null/);
// Öffentliche Karten (Profil, Vergleich, Podium, Galerie) nur über die öffentlichen RPCs
for(const r of ['get_performance_card','get_card_gallery'])assert.match(js,new RegExp("rpc\\('"+r+"'"));
// Bewertungsseite: eigene Ansicht echt + (öffentlich); Trainer-Ansichten nur öffentlich
const own=bew.slice(bew.indexOf('function ownView'),bew.indexOf('// Etappe 10'));
assert.match(own,/pubTag\(pb\.overall\)/);assert.match(bew,/const coachView=\(\)=>edit\.mode!=='self'&&edit\.bestOthers!==undefined;/);
assert.match(bew,/const pubOv=b=>b\.public_overall!=null\?b\.public_overall:b\.overall;/);
assert.doesNotMatch(bew,/b\.public_overall!=null\?' '\+pubTag/,'staff list without real value');
assert.match(bew,/r\.pub_overall\?\?r\.overall/);assert.match(bew,/changeText\(before,pubBefore\(bid\),data\)/);
console.log('PASS: Etappe 17b – Studio-Kachel, Holo- und Design-Vorschau öffentlich, öffentliche Karten nur über öffentliche RPCs, eigene Bewertungsseite echt (öffentlich), Trainer-Liste, Vorschau, Selbsteinschätzungen und Meldungen öffentlich');
