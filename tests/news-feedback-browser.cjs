'use strict';
// Real Chromium test with mocked Supabase SDK (no real account, no server writes) for Etappe 7b:
// news page from news.json with unread marker in the menu, feedback form with screenshot upload,
// own reports with reply, admin inbox with status and reply.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const NEWS={generated_at:'2026-10-28T12:00:00Z',entries:[
 {n:57,date:'2026-10-28',items:[{type:'neu',text:'Feedback-Portal: Fehler und Ideen direkt melden, mit Screenshots.'},{type:'behoben',text:'<b>Kein</b> HTML in News'}]},
 {n:56,date:'2026-10-27',items:[{type:'verbessert',text:'Boxervergleich mit Spielerkarten.'}]}]};
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1');
 if(u.pathname==='/news.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(NEWS));return}
 const file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
const PNG='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
function injected(cfg){
 const calls=[];window.__calls=calls;const uploads=[];window.__uploads=uploads;
 const role=cfg.role,uid='u-'+role;
 let items=cfg.role==='boxer'?[{id:'f-old',kind:'idea',title:'Dunkler Kalender',message:'Bitte dunkler.',page:null,attachments:['u-boxer/aaaaaaaa1111.jpg'],status:'done',reply:'Ist umgesetzt, danke!',replied_at:'2026-10-27T10:00:00Z',created_at:'2026-10-25T10:00:00Z'}]:[];
 let inbox=[{id:'f1',kind:'bug',title:'Speichern hängt',message:'<img src=x onerror=window.__xss=1>Dreht endlos',page:'boxer.html',device:'iOS · Safari · 390×844',author:'Anna',attachments:['u-anna/bbbbbbbb2222.jpg'],status:'open',reply:null,created_at:'2026-10-28T09:00:00Z'}];
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='my_app_feedback')return {data:{enabled:true,is_admin:role==='admin',items},error:null};
  if(name==='submit_app_feedback'){const x={id:'f-new',kind:args.p_kind,title:args.p_title,message:args.p_message,page:args.p_page,attachments:args.p_attachments,status:'open',reply:null,created_at:new Date().toISOString()};items=[x,...items];return {data:x,error:null}}
  if(name==='admin_list_app_feedback')return {data:{counts:{open:inbox.filter(x=>x.status==='open').length,in_progress:0,done:inbox.filter(x=>x.status==='done').length,rejected:0},items:inbox.filter(x=>!args.p_status||x.status===args.p_status)},error:null};
  if(name==='admin_update_app_feedback'){const x=inbox.find(i=>i.id===args.p_id);x.status=args.p_status;x.reply=args.p_reply;return {data:{...x},error:null}}
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const storage={from:b=>({upload:async(p,blob,o)=>{uploads.push([b,p,o&&o.contentType,blob.size,o&&o.upsert]);return {data:{path:p},error:null}},
  createSignedUrls:async(paths)=>({data:paths.map(p=>({path:p,signedUrl:'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='})),error:null})})};
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle:async()=>({data:{role,is_active:true,display_name:role==='admin'?'Bendo':'Anna'},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:cfg.signedIn?{access_token:'x'}:null}}),getUser:async()=>({data:{user:cfg.signedIn?{id:uid}:null},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
  from:()=>q,rpc,storage};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 async function page(cfg){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
  return {p,errors,context};
 }
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 // A: Menü zeigt «Neu», News-Seite markiert Ungelesenes und merkt sich den Stand
 let {p,errors,context}=await page({role:'boxer',signedIn:true});
 // Takeover 3.0: Punkt am Menüknopf der App-Shell, «Neu» und Feedback-Herkunft im Menü
 await p.goto(base+'goals.html');await p.waitForSelector('#tla-account-btn.tla-has-news',{state:'attached'});
 await p.click('#tla-account-btn');await p.waitForSelector('#tla-drawer:not([hidden])');
 assert.match(await p.textContent('#tla-drawer a[href="./news.html"]'),/Neu/);
 assert.equal(await p.getAttribute('#tla-drawer a[href^="./feedback.html"]','href'),'./feedback.html?from=goals.html');
 await p.goto(base+'news.html');await p.waitForSelector('.news-entry');
 assert.equal(await p.locator('.news-entry.unread').count(),2);
 const txt=await p.textContent('#app');assert.match(txt,/Feedback-Portal: Fehler und Ideen/);assert.match(txt,/<b>Kein<\/b> HTML/,'text shown literally');
 assert.equal(await p.locator('.news-items b').count(),0,'no HTML injection');
 assert.equal(await p.evaluate(()=>localStorage.getItem('tl.news.seen')),'57');
 await shot(p,'7b-news');await noOverflow(p);
 await p.goto(base+'goals.html');await p.waitForSelector('#tla-account-btn');await p.waitForTimeout(500);
 assert.equal(await p.locator('#tla-account-btn.tla-has-news').count(),0,'read → no dot');
 assert.deepEqual(errors,[]);await context.close();

 // B: Boxer meldet einen Fehler mit Screenshot
 ({p,errors,context}=await page({role:'boxer',signedIn:true}));
 await p.goto(base+'feedback.html?from=boxer.html');await p.waitForSelector('.fb-form');
 assert.match(await p.textContent('.fb-form'),/Seite boxer\.html/);
 await p.fill('input[name="fbTitle"]','Speichern hängt');
 await p.setInputFiles('[data-files]',{name:'shot.png',mimeType:'image/png',buffer:Buffer.from(PNG,'base64')});
 await p.waitForSelector('.fb-file img');
 assert.equal(await p.inputValue('input[name="fbTitle"]'),'Speichern hängt','draft kept while adding an image');
 await p.click('.fb-kind:has(input[value="display"])');
 await p.fill('textarea[name="fbMessage"]','Der Knopf dreht endlos.');
 await shot(p,'7b-feedback-form');
 await p.click('button[type="submit"]');
 await p.waitForFunction(()=>/Danke! Deine Meldung ist angekommen/.test(document.getElementById('status').textContent));
 const up=await p.evaluate(()=>window.__uploads);
 assert.equal(up.length,1);assert.equal(up[0][0],'feedback-shots');assert.match(up[0][1],/^u-boxer\/[0-9a-f]{18}\.jpg$/);assert.equal(up[0][2],'image/jpeg');assert.equal(up[0][4],false);
 const sub=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='submit_app_feedback')[1];
 assert.equal(sub.p_kind,'display');assert.equal(sub.p_title,'Speichern hängt');assert.equal(sub.p_page,'boxer.html');assert.deepEqual(sub.p_attachments,[up[0][1]]);assert.match(sub.p_device,/×/);
 assert.match(await p.textContent('#app'),/Meine Meldungen \(2\)[\s\S]*Speichern hängt[\s\S]*Dunkler Kalender[\s\S]*Ist umgesetzt, danke!/);
 assert.equal(await p.locator('.fb-thumbs img').count(),2,'new + old report with one screenshot each');
 await shot(p,'7b-feedback-mine');await noOverflow(p);assert.deepEqual(errors,[]);await context.close();

 // C: Admin-Eingang: Status und Antwort, Inhalte escaped
 ({p,errors,context}=await page({role:'admin',signedIn:true}));
 await p.goto(base+'feedback.html?view=inbox');await p.waitForSelector('[data-item="f1"]');
 assert.equal(await p.textContent('#pageTitle'),'Feedback & Eingang');
 const inbox=await p.textContent('[data-item="f1"]');assert.match(inbox,/Anna/);assert.match(inbox,/iOS · Safari/);assert.match(inbox,/<img src=x/);
 assert.equal(await p.evaluate(()=>window.__xss),undefined,'no script from report text');
 await p.selectOption('[data-item="f1"] [data-status]','done');await p.fill('[data-item="f1"] [data-reply]','Behoben, bitte neu laden.');
 await p.click('[data-save="f1"]');
 await p.waitForFunction(()=>/Gespeichert: «Speichern hängt» ist erledigt/.test(document.getElementById('status').textContent));
 const upd=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='admin_update_app_feedback')[1];
 assert.deepEqual(upd,{p_id:'f1',p_status:'done',p_reply:'Behoben, bitte neu laden.'});
 await shot(p,'7b-feedback-inbox');await noOverflow(p);assert.deepEqual(errors,[]);await context.close();

 // D: Gast sieht nur den Anmelde-Hinweis, Menü ohne Feedback-Link
 ({p,errors,context}=await page({role:'boxer',signedIn:false}));
 await p.goto(base+'feedback.html');await p.waitForFunction(()=>/anmelden/.test(document.getElementById('app').textContent));
 assert.ok(!(await p.evaluate(()=>window.__calls)).length,'guest triggers no rpc');
 await p.click('#tla-account-btn');await p.waitForSelector('#tla-drawer:not([hidden])');
 assert.equal(await p.locator('#tla-drawer a[href^="./feedback.html"]').count(),0,'guest menu without feedback');
 await context.close();

 await browser.close();server.close();
 console.log('PASS: Neuigkeiten mit Ungelesen-Punkt, Feedback mit Screenshot-Upload in den eigenen Ordner, eigene Meldungen mit Antwort, Admin-Eingang mit Status/Antwort, Gast ohne Zugriff – im Browser geprüft');
})().catch(e=>{console.error(e);process.exit(1)});
