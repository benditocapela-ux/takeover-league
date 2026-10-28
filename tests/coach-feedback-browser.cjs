'use strict';
// Chromium test with mocked Supabase SDK (no real account, no server writes) for Etappe 6b:
// Coach-Dashboard kompakt (Bereiche geordnet, auf-/zuklappbar und gemerkt, Sprungleiste, nur die letzten 5),
// Feedback mit «sichtbar bis», sofort archivieren, zurückziehen/wiederherstellen; Boxer sieht aktive Feedbacks und das Archiv.
// Basis-Mock aus tests/release-auth-ui-mocked.cjs (bewährt für coach.html und boxer.html), ergänzt um die neuen RPCs.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,(u.pathname==='/'?'index.html':decodeURIComponent(u.pathname.slice(1))));
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
 const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':'application/octet-stream');res.end(data)});
});
const base=fs.readFileSync(path.join(__dirname,'release-auth-ui-mocked.cjs'),'utf8');
const start=base.indexOf('function injected(role){');let injectedSrc=base.slice(start,base.indexOf('\n}\n',start)+2);
assert.ok(start>0&&injectedSrc.includes("{feature_key:'coach_feedback',is_enabled:false}"),'base mock found');
injectedSrc=injectedSrc.replace("{feature_key:'coach_feedback',is_enabled:false}","{feature_key:'coach_feedback',is_enabled:true}")
 .replace('rpc:async(name,args)=>{','rpc:async(name,args)=>{const __x=window.__extraRpc&&window.__extraRpc(name,args);if(__x)return __x;');
assert.ok(injectedSrc.includes('window.__extraRpc'),'rpc hook');
function extra(){
 const today=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich'}).format(new Date());
 const add=(s,n)=>{const d=new Date(s+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
 const dow=((new Date(today+'T12:00:00Z').getUTCDay()+6)%7)+1;
 const calls=[];window.__extraCalls=calls;
 const fb=[{id:'f1',title:'Deckung hoch',message:'Linke Hand oben lassen.',created_at:add(today,-2)+'T18:00:00Z',visible_until:add(today,5),coach:'Test Admin',status:'active',boxer_id:'b1',boxer:'Test Boxer',can_edit:true},
  {id:'f2',title:'Alt',message:'Älteres Feedback',created_at:'2026-10-18T18:00:00Z',visible_until:'2026-10-25',coach:'Marco',status:'archived',boxer_id:'b1',boxer:'Test Boxer',can_edit:false}];
 window.__extraRpc=(name,args)=>{
  if(!['get_my_feedback','staff_list_feedback','staff_update_feedback','get_club_schedule','coach_training_audit_recent','coach_list_training_history','coach_list_boxers'].includes(name))return null;
  calls.push([name,args]);
  if(name==='coach_list_training_history'||name==='coach_training_audit_recent')return null; // Basis-Mock antwortet, Aufruf wird nur protokolliert
  if(name==='coach_list_boxers')return Promise.resolve({data:[{id:'11111111-1111-4111-8111-111111111111',display_name:'Test Boxer',role:'boxer',is_active:true},{id:'22222222-2222-4222-8222-222222222222',display_name:'Test Admin',role:'admin',is_active:true}],error:null});
  if(name==='get_my_feedback')return Promise.resolve({data:{enabled:true,today,active:fb.filter(x=>x.status==='active'),archived:fb.filter(x=>x.status==='archived')},error:null});
  if(name==='staff_list_feedback')return Promise.resolve({data:fb.map(x=>({...x})),error:null});
  if(name==='staff_update_feedback'){const x=fb.find(f=>f.id===args.p_feedback_id);if(args.p_visible_until)x.visible_until=args.p_visible_until;
   if(args.p_withdrawn===true)x.status='withdrawn';else if(args.p_withdrawn===false)x.status=x.visible_until>=today?'active':'archived';else x.status=x.visible_until>=today?'active':'archived';
   return Promise.resolve({data:{...x},error:null})}
  if(name==='get_club_schedule')return Promise.resolve({data:{enabled:true,preview:false,today,today_dow:dow,can_edit:true,tiers:[],home:{},club_types:[],
   slots:[{id:1,dow,day:dow-1,label:'Technik / Pratzen',training_type:'Techniktraining',training_type_id:2,tier:'pflicht',tier_label:'Pflichttraining',duration_minutes:90,is_active:true,today_session:{id:5,status:'open'}}]},error:null});
  return null;
 };
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const url='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch();
 const context=await browser.newContext({viewport:{width:390,height:844}});
 const open=async(role,file)=>{
  const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript({content:'('+extra.toString()+')();('+injectedSrc+')('+JSON.stringify(role)+')'});
  await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  page.on('dialog',d=>d.accept());
  await page.goto(url+'/'+file);return {page,errors};
 };
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};

 // Coach-Dashboard: Reihenfolge, Standard auf/zu, Sprungleiste, nur die letzten 5
 let {page,errors}=await open('admin','coach.html');
 await page.waitForFunction(()=>!document.querySelector('#content').classList.contains('hidden')&&document.querySelector('[data-sec="audit"]'));
 const layout=await page.evaluate(()=>[...document.querySelectorAll('#content [data-sec]')].map(s=>({key:s.dataset.sec,order:Number(getComputedStyle(s).order),closed:s.classList.contains('is-closed')})).sort((a,b)=>a.order-b.order));
 assert.deepEqual(layout.map(x=>x.key),['pending','gym','entry','feedback','edit','audit']);
 assert.deepEqual(layout.map(x=>x.closed),[false,false,true,true,true,true],'only open trainings and gym today open by default');
 assert.ok(await page.isHidden('#allEntries'),'edit list hidden while collapsed');assert.ok(await page.isHidden('#coachAuditEntries'),'audit hidden while collapsed');
 assert.match(await page.textContent('.coach-jump'),/Offene Trainings1Gym heute.*Änderungshistorie/);
 assert.match(await page.textContent('.gym-today'),/Technik \/ Pratzen · Pflichttraining · 90 Min\.\s*läuft/);
 await page.waitForFunction(()=>window.__extraCalls.some(c=>c[0]==='coach_training_audit_recent'));
 const ex=await page.evaluate(()=>window.__extraCalls);
 assert.equal(ex.find(c=>c[0]==='coach_list_training_history')[1].p_limit,5);
 assert.equal(ex.find(c=>c[0]==='coach_training_audit_recent')[1].p_limit,5);
 await shot(page,'6b-coach-closed');
 // Aufklappen über die Sprungleiste, Zustand wird gemerkt
 await page.click('.coach-jump [data-jump="edit"]');
 assert.ok(await page.isVisible('#allEntries'));assert.ok(await page.isHidden('#showMore'),'no «more» without filter');
 assert.equal(await page.getAttribute('[data-sec="edit"] .tl-col-toggle','aria-expanded'),'true');assert.equal(await page.getAttribute('[data-sec="edit"] .tl-col-toggle','title'),'Zuklappen');
 await page.click('[data-sec="pending"] .tl-col-toggle');
 assert.ok(await page.evaluate(()=>document.querySelector('[data-sec="pending"]').classList.contains('is-closed')));
 await page.reload();
 await page.waitForFunction(()=>document.querySelector('[data-sec="audit"]'));
 assert.deepEqual(await page.evaluate(()=>['pending','edit'].map(k=>document.querySelector('[data-sec="'+k+'"]').classList.contains('is-closed'))),[true,false],'state remembered');

 // Feedback: senden mit «sichtbar bis», archivieren, zurückziehen, wiederherstellen
 await page.click('.coach-jump [data-jump="feedback"]');
 await page.waitForSelector('.fb-row');
 const vis=page.locator('input[name="feedbackVisibleUntil"]');
 const def=await vis.inputValue(),today=await page.evaluate(()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich'}).format(new Date()));
 assert.equal(Math.round((new Date(def)-new Date(today))/864e5),7,'default +7 days');
 assert.match(await page.textContent('#coachFeedbackHistory'),/Deckung hoch\s*aktiv[\s\S]*Alt\s*archiviert/);
 assert.equal(await page.locator('.fb-row').nth(1).locator('button').count(),0,'not author → no actions');
 await page.selectOption('#coachFeedbackBoxer',{index:1});await page.fill('#coachFeedbackTitle','Fokus');await page.fill('#coachFeedbackMessage','Jab doppeln');
 await vis.fill(await page.evaluate(()=>{const d=new Date();d.setUTCDate(d.getUTCDate()+14);return d.toISOString().slice(0,10)}));
 await page.click('#coachFeedbackSend');
 await page.waitForFunction(()=>/Feedback gesendet · sichtbar bis/.test(document.getElementById('coachFeedbackStatus').textContent));
 const sent=await page.evaluate(()=>window.__mockStats.submitted.at(-1));
 assert.equal(sent.title,'Fokus');assert.match(sent.visible_until,/^\d{4}-\d{2}-\d{2}$/);
 assert.equal(await vis.inputValue(),def,'reset to +7 after sending');
 await shot(page,'6b-coach-feedback');
 await page.locator('.fb-row').first().getByRole('button',{name:'Jetzt archivieren'}).click();
 await page.waitForFunction(()=>/archiviert/.test(document.getElementById('coachFeedbackStatus').textContent));
 let up=(await page.evaluate(()=>window.__extraCalls)).filter(c=>c[0]==='staff_update_feedback');
 assert.equal(up.at(-1)[1].p_withdrawn,null);assert.equal(Math.round((new Date(up.at(-1)[1].p_visible_until)-new Date(today))/864e5),-1,'archive = yesterday');
 await page.locator('.fb-row').first().getByRole('button',{name:'Zurückziehen'}).click();
 await page.waitForFunction(()=>/zurückgezogen/.test(document.getElementById('coachFeedbackStatus').textContent));
 up=(await page.evaluate(()=>window.__extraCalls)).filter(c=>c[0]==='staff_update_feedback');
 assert.equal(up.at(-1)[1].p_withdrawn,true);
 assert.ok(await page.locator('.fb-row.is-withdrawn').first().isVisible());
 await page.locator('.fb-row').first().getByRole('button',{name:'Wiederherstellen'}).click();
 await page.waitForFunction(()=>!document.querySelector('.fb-row.is-withdrawn'));
 assert.ok((await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth))<=5,'no horizontal overflow');
 assert.deepEqual(errors,[]);await page.close();

 // Boxer: aktives Feedback oben mit «sichtbar bis», Archiv zugeklappt
 ({page,errors}=await open('boxer','boxer.html'));
 await page.waitForSelector('#boxerFeedbackList .feedback-note',{state:'attached'});
 const fbText=await page.textContent('#boxerFeedbackList');
 assert.match(fbText,/Deckung hoch[\s\S]*sichtbar bis/);
 assert.ok(await page.locator('#boxerFeedbackList details.feedback-archive').count()===1);
 assert.match(await page.textContent('#boxerFeedbackList details.feedback-archive summary'),/Archivierte Feedbacks \(1\)/);
 assert.equal(await page.evaluate(()=>document.querySelector('#boxerFeedbackList details.feedback-archive').open),false,'archive collapsed');
 if(process.env.SHOTS){await page.evaluate(()=>{const s=document.getElementById('boxerFeedbackSection');let e=s;while(e){if(e.hidden)e.hidden=false;e.classList&&e.classList.remove('hidden');e=e.parentElement}});await page.locator('#boxerFeedbackSection').screenshot({path:process.env.SHOTS+'/6b-boxer-feedback.png'})}
 assert.deepEqual(errors,[]);
 await context.close();await browser.close();server.close();
 console.log('PASS: Etappe 6b im Browser – Coach-Dashboard geordnet (Offen/Gym offen, Rest zu), Zustand gemerkt, Sprungleiste, nur letzte 5 Trainings/Änderungen, Feedback mit «sichtbar bis» (Vorgabe 7 Tage), archivieren, zurückziehen, wiederherstellen; Boxer sieht aktive Feedbacks und das Archiv');
})().catch(e=>{console.error(e);server.close();process.exit(1)});
