'use strict';
const fs=require('fs'),path=require('path'),http=require('http'),os=require('os'),assert=require('assert/strict');
const source=fs.readFileSync('tests/boxer-holo-browser.cjs','utf8').replace(/\r\n/g,'\n');
const injected=source.slice(source.indexOf('function injected(cfg){'),source.indexOf('\n(async()=>'));
const sql=fs.readFileSync('supabase/migrations/20261029140000_boxer_holo.sql','utf8');
const ins=sql.slice(sql.indexOf('INSERT INTO public.holo_items'),sql.indexOf('ON CONFLICT (key) DO NOTHING;'));
const items=[...ins.matchAll(/\('([a-z_]+)','([a-z]+)','((?:[^']|'')*)','([a-z]+)','([a-z]+)',(NULL|\d+),(NULL|'(\{[^']*\})'),(\d+)\)/g)].map(m=>({key:m[1],slot:m[2],value:m[1].slice(m[2].length+1),name:m[3],owned:true,price:0}));
const defaults={tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',top:'none',topc:'schwarz',hood:false,bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',feet:'boots',feetc:'schwarz',coat:'samurai',aura:'none',eyefx:'none',scene:'holo',pose_profile:'guard',pose_card:'guard'};
(async()=>{
 let server,dir,base=process.env.LIVE_BASE;
 if(!base){dir=fs.mkdtempSync(path.join(os.tmpdir(),'premium-live-'));require('../tools/assemble-pages-site.cjs').assemble(process.cwd(),dir);server=http.createServer((req,res)=>{const file=path.resolve(dir,'.'+new URL(req.url,'http://local').pathname);if(!file.startsWith(dir+path.sep)){res.writeHead(403);return res.end()}fs.readFile(file,(e,data)=>{if(e){res.writeHead(404);return res.end()}res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.json':'application/json','.css':'text/css','.png':'image/png','.svg':'image/svg+xml','.woff':'font/woff'})[path.extname(file)]||'application/octet-stream');res.end(data)})});await new Promise(r=>server.listen(0,'127.0.0.1',r));base='http://127.0.0.1:'+server.address().port+'/'}
 const output=process.env.SHOTS||path.join(os.tmpdir(),'premium-live-evidence');fs.mkdirSync(output,{recursive:true});
 try{for(const engine of (process.env.BROWSER||'chromium,webkit').split(',')){
 const browser=await require('playwright')[engine].launch();
 try{const context=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});await context.addInitScript({content:'('+injected+')('+JSON.stringify({visualDemo:true,items,saved:defaults})+')'});
 const page=await context.newPage(),errors=[],missing=[];page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.url().startsWith(base)&&r.status()>=400&&!r.url().endsWith('news.json'))missing.push(r.url())});
 await page.route('**/*',r=>{const u=r.request().url();if(u.startsWith(base)||/^(data:|blob:)/.test(u))return r.continue();if(u.includes('@supabase/supabase-js'))return r.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'});return r.fulfill({contentType:'application/json',body:'[]'})});
 await page.goto(base+'mein-boxer.html');await page.waitForSelector('[data-premium-character="anime"]',{timeout:90000});
 const choose=async(field,value)=>{const tab=['pose_profile','pose_card'].includes(field)?'posen':['hair','tone','hc','eye'].includes(field)?'koerper':'kleidung';if(await page.locator('[data-tab="'+tab+'"]').count())await page.locator('[data-tab="'+tab+'"]').click();const button=page.locator('[data-set="'+field+'"][data-val="'+value+'"]');await button.focus();await page.keyboard.press('Enter')};
 const anime=async()=>page.waitForSelector('[data-premium-character="anime"]',{timeout:90000});
 const before=await page.locator('[data-premium-character] img').getAttribute('src');
 await choose('bottomc','rot');await page.waitForFunction(old=>document.querySelector('[data-premium-character] img')?.src!==old&&!!document.querySelector('[data-premium-character]'),before,{timeout:90000});
 await page.screenshot({path:path.join(output,engine+'-guard.png'),fullPage:true});
 await choose('pose_profile','cool');await page.waitForSelector('[data-artpack-pose="cool"][data-premium-character]',{timeout:90000});
 await page.locator('[data-tab="kleidung"]').click();
 const coatToggle=page.locator('[data-toggle="coat"]');await coatToggle.click();await anime();
 await choose('top','shirt');await anime();
 await page.waitForFunction(()=>document.querySelector('[data-set="top"][data-val="shirt"] .mb-item-status')?.dataset.renderer==='anime',{timeout:90000});
 assert.equal(await page.locator('[data-set="top"][data-val="shirt"] .mb-premium-item').count(),1);
 await page.screenshot({path:path.join(output,engine+'-cool-shirt.png'),fullPage:true});
 await choose('pose_profile','jab');await page.waitForSelector('.mb-preview svg.tlh');assert.equal(await page.locator('[data-premium-character]').count(),0);
 await page.locator('[data-tab="kleidung"]').click();assert.equal(await page.locator('[data-set="top"][data-val="shirt"] .mb-item-status').getAttribute('data-renderer'),'svg');
 await choose('pose_profile','guard');await anime();
 await page.locator('[data-tab="kleidung"]').click();await coatToggle.click();await page.waitForSelector('.mb-preview svg.tlh');
 await choose('top','none');await anime();
 assert.deepEqual(errors,[]);assert.deepEqual(missing,[]);assert.equal(await page.evaluate(()=>window.__calls.some(c=>c[0]==='save_my_holo'||c[0].startsWith('buy_'))),false,'no account writes');
 await context.close();
 const broken=await browser.newContext({viewport:{width:390,height:844}});await broken.addInitScript({content:'('+injected+')('+JSON.stringify({visualDemo:true,items,saved:defaults})+')'});
 await broken.route('**/*',r=>{const u=r.request().url();if(u.startsWith(base)){if(u.includes('/assets/premium-character/')&&u.endsWith('.png'))return r.fulfill({status:404,body:'missing'});return r.continue()}if(u.includes('@supabase/supabase-js'))return r.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'});return r.fulfill({contentType:'application/json',body:'[]'})});
 const bp=await broken.newPage();await bp.goto(base+'mein-boxer.html');await bp.waitForSelector('.mb-preview svg.tlh');await bp.waitForFunction(()=>window.TLPremiumProduction?.loader.stats().failures>0);assert.equal(await bp.locator('[data-premium-character]').count(),0);await broken.close();
 console.log('PASS '+engine+': released editor, Guard/Cool, red pants, shirt tile parity, unsupported pose/coat fallback, restored anime, missing-image fallback, no persistence; '+base);
 }finally{await browser.close()}}
 }finally{if(server)await new Promise(r=>server.close(r));if(dir)fs.rmSync(dir,{recursive:true,force:true})}
})().catch(e=>{console.error(e);process.exit(1)});
