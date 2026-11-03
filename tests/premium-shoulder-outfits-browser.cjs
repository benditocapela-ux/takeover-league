'use strict';
// Verify the shipped adapter, not a second thumbnail implementation.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),out=path.join(root,'output/shoulder-qa');fs.mkdirSync(out,{recursive:true});
const site=fs.mkdtempSync(path.join(out,'site-')),build=require('../tools/assemble-pages-site.cjs').assemble(root,site);
const fixture=fs.readFileSync(path.join(root,'tests/boxer-holo-browser.cjs'),'utf8').replace(/\r\n/g,'\n'),accountFixture=fixture.slice(fixture.indexOf('function injected(cfg){'),fixture.indexOf('\n(async()=>'));
const sql=fs.readFileSync(path.join(root,'supabase/migrations/20261029140000_boxer_holo.sql'),'utf8'),catalogueSQL=sql.slice(sql.indexOf('INSERT INTO public.holo_items'),sql.indexOf('ON CONFLICT (key) DO NOTHING;'));
const catalogue=[...catalogueSQL.matchAll(/\('([a-z_]+)','([a-z]+)','((?:[^']|'')*)','([a-z]+)','([a-z]+)',(NULL|\d+),(NULL|'(\{[^']*\})'),(\d+)\)/g)].map(m=>({key:m[1],slot:m[2],value:m[1].slice(m[2].length+1),name:m[3],rarity:m[4],unlock:m[5],price:m[6]==='NULL'?null:+m[6]}));
const server=http.createServer((req,res)=>{const name=new URL(req.url,'http://local').pathname.slice(1);if(name==='fixture.html'){const meta=fs.readFileSync(path.join(site,'mein-boxer.html'),'utf8').match(/<meta name="tl-premium-character"[^>]*>/)[0];res.setHeader('Content-Type','text/html');return res.end('<!doctype html><html><head>'+meta+'<script src="./takeover-holo.js"></script></head><body><script type="module">window.adapter=await(await import("./takeover-premium-character.js")).init();document.body.dataset.ready="true"</script></body></html>')}const file=path.resolve(site,name);if(!file.startsWith(site+path.sep)){res.writeHead(403);return res.end()}fs.readFile(file,(e,b)=>{if(e){res.writeHead(404);return res.end()}res.setHeader('Content-Type',({'.js':'text/javascript','.json':'application/json','.html':'text/html','.png':'image/png','.css':'text/css'})[path.extname(file)]||'application/octet-stream');res.end(b)})});
const choices=[['top','hoodie',false],['top','hoodie',true],['top','jacke',false],...['samurai','basic','neon','drache'].map(c=>['coat',c,false])];
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port,report={version:build.premium.version,engines:[]};try{for(const engine of (process.env.BROWSER||'chromium,webkit').split(',')){
 const browser=await require('playwright')[engine].launch();try{
  const page=await browser.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(base+'/fixture.html');await page.waitForFunction(()=>document.body.dataset.ready==='true');
  const result=await page.evaluate(async choices=>{
   const P=TLPremiumCompletion,rows=[];
   async function rgba(url){const im=new Image();im.src=url;await im.decode();const c=document.createElement('canvas');c.width=im.naturalWidth;c.height=im.naturalHeight;const g=c.getContext('2d');g.drawImage(im,0,0);return {w:c.width,h:c.height,data:g.getImageData(0,0,c.width,c.height).data}}
   for(const pose of ['sieg','ansage'])for(const [slot,value,hood]of choices)for(const color of ['schwarz','rot','weiss']){
    const c={...P.defaults,pose_profile:pose,top:slot==='top'?value:'none',topc:color,coat:slot==='coat'?value:'none',hood,feet:'sneaker',feetc:color},r=await P.prepare(c);if(r.renderer!=='anime-draft')throw Error('Missing outfit '+JSON.stringify(c));
    const frame=P.itemFrame(r.selection,slot),full=document.createElement('canvas');full.width=768;full.height=1216;P.draw(full.getContext('2d'),r.selection,r.images,slot);
    const tile=document.createElement('canvas'),scale=Math.min(1,180/Math.max(frame[2],frame[3]));tile.width=Math.max(1,Math.round(frame[2]*scale));tile.height=Math.max(1,Math.round(frame[3]*scale));tile.getContext('2d').drawImage(full,...frame,0,0,tile.width,tile.height);
    const expected=tile.toDataURL(),html=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Item timeout')),15000),ready=()=>{const html=adapter.item(c,pose,slot,ready);if(html){clearTimeout(timer);resolve(html)}};ready()}),actual=/src="([^"]+)"/.exec(html)[1],a=await rgba(expected),b=await rgba(actual);
    if(a.w!==b.w||a.h!==b.h||a.data.some((v,i)=>v!==b.data[i]))throw Error('Different item pixels '+pose+'/'+slot+'/'+value+'/'+color);
    const selected=r.selection.pieces.filter(p=>slot==='coat'?['coatFront','coatBack'].includes(p.slot):p.slot===slot),sources=[...new Set(selected.map(p=>p.src))];
    if(!sources.some(src=>src.includes('completion/assets/'+(slot==='top'?value:'coat'+(value==='samurai'?'':'-'+value))+'-'+pose+'.png')))throw Error('Wrong garment source');
    rows.push({pose,slot,value,hood,color,sources,exactItem:true});
   }
   return {rows};
  },choices);
  assert.deepEqual(errors,[]);await page.close();
  let fallback=0,editorChanges=0;
  async function context(saved,failed,width){const ctx=await browser.newContext({viewport:{width,height:844},reducedMotion:'reduce'});await ctx.addInitScript({content:'('+accountFixture+')('+JSON.stringify({visualDemo:true,items:catalogue,saved})+')'});await ctx.route('**/*',route=>{const url=route.request().url();if(url.startsWith(base)){if(failed&&new URL(url).pathname.endsWith(failed))return route.fulfill({status:404,body:'synthetic unavailable garment'});return route.continue()}if(url.includes('@supabase/supabase-js'))return route.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'});if(/^(data:|blob:)/.test(url))return route.continue();return route.fulfill({contentType:'application/json',body:'[]'})});return ctx}
  for(const [i,pose]of ['sieg','ansage'].entries()){
   const saved={pose_profile:pose,top:'hoodie',topc:'schwarz',coat:'none',hood:false,feet:'sneaker'},ctx=await context(saved,null,i?412:390),p=await ctx.newPage(),editorErrors=[];p.on('pageerror',e=>editorErrors.push(e.message));await p.goto(base+'/mein-boxer.html?tab=kleidung');
   for(const [slot,value]of choices.filter(([,v,h])=>!h)){
    await p.locator('[data-set="'+(slot==='coat'?'coatPick':slot)+'"][data-val="'+value+'"]').focus();await p.keyboard.press('Enter');
    await p.waitForSelector('.mb-preview [data-premium-character][data-artpack-pose="'+pose+'"]',{timeout:60000});
    await p.waitForFunction(({slot,value})=>document.querySelector('[data-set="'+(slot==='coat'?'coatPick':slot)+'"][data-val="'+value+'"] .mb-item-status')?.dataset.renderer==='anime',{slot,value});
    assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));editorChanges++;
   }
   await p.screenshot({path:path.join(out,engine+'-'+pose+'-editor.png')});assert.deepEqual(editorErrors,[]);assert.equal(await p.evaluate(()=>__calls.some(c=>c[0]==='save_my_holo'||c[0].startsWith('buy_'))),false);await ctx.close();
   for(const [slot,value]of choices.filter(([,v,h])=>!h)){
    const source='completion/assets/'+(slot==='top'?value:'coat'+(value==='samurai'?'':'-'+value))+'-'+pose+'.png',initial={...saved,top:slot==='top'?value:'none',coat:slot==='coat'?value:'none'},ctx=await context(initial,source,390),p=await ctx.newPage();await p.goto(base+'/mein-boxer.html?tab=kleidung');
    await p.waitForFunction(({slot,value})=>document.querySelector('[data-set="'+(slot==='coat'?'coatPick':slot)+'"][data-val="'+value+'"] .mb-item-status')?.dataset.renderer==='svg',{slot,value},{timeout:60000});
    await p.waitForSelector('.mb-preview svg.tlh');assert.equal(await p.locator('.mb-preview [data-premium-character],[data-set="'+(slot==='coat'?'coatPick':slot)+'"][data-val="'+value+'"] .mb-premium-item').count(),0,'Missing garment yields complete SVG hero and truthful tile');assert.equal(await p.evaluate(()=>__calls.some(c=>c[0]==='save_my_holo'||c[0].startsWith('buy_'))),false);fallback++;await ctx.close();
   }
  }
  report.engines.push({engine,exactItems:result.rows.length,editorChanges,fullSVGFallbacks:fallback,rows:result.rows});console.log('PASS '+engine+': '+result.rows.length+' exact outerwear tiles; '+editorChanges+' mobile editor changes; '+fallback+' missing garments fully SVG');
 }finally{await browser.close()}
 }fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');}finally{server.close()}})().catch(e=>{console.error(e);server.close();process.exitCode=1});
