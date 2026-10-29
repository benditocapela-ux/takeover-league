'use strict';
// Chromium test (mocked Supabase, no server writes) for Etappe 17a: im Trainingsformular sind alle Trainingsarten wählbar,
// solange «Vereinstrainings nur per Gym-Check-in» aus ist; mit dem Schalter an verschwinden die Vereinstrainings (Hinweis sichtbar).
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,(u.pathname==='/'?'index.html':decodeURIComponent(u.pathname.slice(1))));
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
// Bewährter Basis-Mock (release-auth-ui-mocked.cjs) mit Vereinstrainings, beiden Schaltern und .in()-Filter
const base=fs.readFileSync(path.join(__dirname,'release-auth-ui-mocked.cjs'),'utf8');
const start=base.indexOf('function injected(role){');let mock=base.slice(start,base.indexOf('\n}\n',start)+2);
const TYPES=JSON.stringify([{id:1,name:'Reguläres Boxtraining',points:30,is_active:true,club_only:true,category:'Boxen',sort_order:110},
 {id:3,name:'Techniktraining',points:30,is_active:true,club_only:true,category:'Boxen',sort_order:120},
 {id:11,name:'Schattenboxen / Heimtraining',points:20,is_active:true,club_only:false,category:'Boxen',sort_order:150},
 {id:6,name:'Joggen',points:20,is_active:true,club_only:false,category:'Ausdauer',sort_order:310}]);
const rep=(a,b)=>{assert.ok(mock.includes(a),'mock part: '+a.slice(0,40));mock=mock.replace(a,b)};
rep("const trainer=[{id:1,name:'Reguläres Boxtraining',points:50,is_active:true},{id:2,name:'Joggen',points:20,is_active:true}];","const trainer="+TYPES+";");
rep("{feature_key:'performance_dashboard',is_enabled:false}]","{feature_key:'performance_dashboard',is_enabled:false},{feature_key:'gym_training',is_enabled:true},{feature_key:'club_checkin_only',is_enabled:window.__clubOnly===true}]");
rep("eq:(col,val)=>{filter.push([col,val]);return self},","eq:(col,val)=>{filter.push([col,val]);return self},in:(col,vals)=>{filter.push([col,{in:vals}]);return self},");
rep("filter.every(([k,v])=>x[k]===v)","filter.every(([k,v])=>v&&v.in?v.in.includes(x[k]):x[k]===v)");
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const url='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 async function open(clubOnly){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript({content:'window.__clubOnly='+(clubOnly?'true':'false')+';('+mock+')("boxer")'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));p.on('dialog',d=>{errors.push('dialog');d.dismiss()});
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await p.goto(url+'boxer.html');await p.waitForFunction(()=>document.querySelectorAll('#kind option').length>0);
  return {p,errors,context};
 }
 const opts=p=>p.locator('#kind option').evaluateAll(es=>es.filter(e=>e.value).map(e=>e.textContent));
 // Schalter aus (Standard): alle Trainingsarten wählbar, kein Hinweis
 let {p,errors,context}=await open(false);
 assert.deepEqual((await opts(p)).sort(),['Joggen','Reguläres Boxtraining','Schattenboxen / Heimtraining','Techniktraining']);
 assert.equal(await p.locator('.club-types-hint').count(),0);
 assert.deepEqual(errors,[]);await context.close();
 // Schalter an: Vereinstrainings nur per Check-in (wie vorher)
 ({p,errors,context}=await open(true));
 assert.deepEqual((await opts(p)).sort(),['Joggen','Schattenboxen / Heimtraining']);
 assert.match(await p.textContent('.club-types-hint'),/Reguläres Boxtraining, Techniktraining/);
 assert.deepEqual(errors,[]);await context.close();
 await browser.close();server.close();
 console.log('PASS: Etappe 17a im Browser – Schalter aus: alle Trainingsarten im Formular; Schalter an: Vereinstrainings ausgeblendet mit Hinweis');
})().catch(e=>{console.error(e);process.exit(1)});
