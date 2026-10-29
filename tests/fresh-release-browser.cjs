'use strict';
// Chromium test for Etappe 20a: nach einem Deploy lädt eine zwischengespeicherte Seite einmal die neue Version
// (meta tl-release ≠ version.json), nie in einer Schleife, nie nach einer Eingabe, nie ohne Versionsangabe (lokal).
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
let served='bbbbbbb2',versionDelay=0;
const page=release=>`<!doctype html><html><head>${release?`<meta name="tl-release" content="${release}">`:''}<meta charset="utf-8"><title>Takeover League</title></head>
<body data-tl-screen="news"><main><h1>Test</h1><input id="f" aria-label="Feld"></main><script src="./takeover-navigation.js"></script></body></html>`;
let htmlRelease='aaaaaaa1';
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1');
 if(u.pathname==='/version.json'){setTimeout(()=>{res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','max-age=600');res.end(JSON.stringify({release:served}))},versionDelay);return}
 if(u.pathname==='/t.html'){res.setHeader('Content-Type','text/html');res.end(page(htmlRelease));return}
 const file=path.resolve(root,decodeURIComponent(u.pathname.slice(1)));
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(e,d)=>{if(e){res.writeHead(404);res.end();return}res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':'application/octet-stream');res.end(d)});
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 async function run(setup){
  const ctx=await browser.newContext();const p=await ctx.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  let loads=0;p.on('load',()=>{loads++});
  if(setup)await setup(p);
  await p.goto(base+'t.html');await p.waitForTimeout(1500);
  const n=loads;await ctx.close();return {loads:n,errors};
 }
 // Alte Seite, neue Version verfügbar: genau ein Neu-Laden (danach meldet die Seite die neue Version)
 htmlRelease='aaaaaaa1';served='bbbbbbb2';
 let r=await run(async p=>{p.on('request',q=>{if(q.url().endsWith('/t.html')&&q.isNavigationRequest()&&q.redirectedFrom()==null){}});
  await p.route('**/t.html',async rt=>{const resp=await rt.fetch();const body=(await resp.text());rt.fulfill({response:resp,body});htmlRelease='bbbbbbb2'})});
 assert.equal(r.loads,2,'reloaded once to the new release');assert.deepEqual(r.errors,[]);
 // Server liefert weiter die alte Seite: kein Endlos-Neuladen (sessionStorage-Sperre)
 htmlRelease='aaaaaaa1';served='bbbbbbb2';
 r=await run();assert.equal(r.loads,2,'only one reload attempt per release');
 // Gleiche Version: nichts
 htmlRelease='bbbbbbb2';served='bbbbbbb2';
 r=await run();assert.equal(r.loads,1);
 // Ohne Versionsangabe (lokal/Tests): keine Abfrage, nichts
 htmlRelease='';r=await run(async p=>{p.on('request',q=>{if(q.url().includes('version.json'))throw new Error('fetched')})});assert.equal(r.loads,1);
 // Nach einer Eingabe nicht neu laden (nichts geht verloren)
 htmlRelease='aaaaaaa1';served='ccccccc3';versionDelay=800;
 const ctx=await browser.newContext();const p=await ctx.newPage();let loads=0;p.on('load',()=>loads++);
 await p.goto(base+'t.html');await p.fill('#f','Hallo');await p.waitForTimeout(1500);
 assert.equal(loads,1,'no reload after typing');assert.equal(await p.inputValue('#f'),'Hallo');
 await ctx.close();
 // Unsinnige Versionsangabe wird ignoriert
 versionDelay=0;served='<script>';htmlRelease='aaaaaaa1';r=await run();assert.equal(r.loads,1);
 await browser.close();server.close();
 console.log('PASS: Etappe 20a im Browser – alte zwischengespeicherte Seite lädt einmal die neue Version, keine Schleife, nichts bei gleicher/fehlender/ungültiger Version, nie nach einer Eingabe');
})().catch(e=>{console.error(e);process.exit(1)});
