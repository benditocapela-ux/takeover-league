// Trainingsauswahl (Mein Studio): Alle Bereichs-Tasten müssen anklickbar sein – auch wenn bereits
// eine Trainingsart ausgewählt ist (Fehlerbericht 27.10.2026: nur «Häufig» und «Boxen» reagierten).
const {chromium}=require('playwright');
const http=require('node:http');const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
const root=path.join(__dirname,'..');
const types=[[1,'Reguläres Boxtraining',50,'Boxen',110],[2,'Wettkampfsparring',70,'Wettkampf',30],[3,'Techniktraining',40,'Boxen',120],[4,'Krafttraining',30,'Athletik',220],
 [5,'Sprint-Intervalle',40,'Athletik',210],[6,'Joggen',20,'Ausdauer',310],[7,'Wettkampf',100,'Wettkampf',10],[8,'Trainingslager / Camp-Tag',80,'Wettkampf',20],
 [9,'Pratzentraining',35,'Boxen',130],[10,'Sandsack / Rundenarbeit',30,'Boxen',140],[11,'Schattenboxen / Heimtraining',20,'Boxen',150],
 [12,'Seilspringen / Konditionszirkel',20,'Athletik',230],[13,'Alternative Ausdauer (Rad, Schwimmen, Rudern)',20,'Ausdauer',320],
 [14,'Trainingsassistenz',30,'Erholung & Team',410],[15,'Mobilität / Regeneration',15,'Erholung & Team',420]]
 .map(([id,name,points,category,sort_order])=>({id,name,points,category,sort_order,is_active:true}));
const history=[1,1,1,3,3,4,6].map((t,i)=>({id:'s'+i,boxer_id:'p1',training_type_id:t,training_date:'2026-10-2'+(i%9),notes:'Training',status:'approved',created_at:'2026-10-20T10:00:00Z'}));
const mock=`
const T=${JSON.stringify({profiles:[{id:'p1',auth_user_id:'u1',display_name:'Ben',role:'boxer',is_active:true,is_listed:true}],training_types:types,training_submissions:history})};
function q(table){let one=false;const b={select(){return b},eq(){return b},neq(){return b},in(){return b},gte(){return b},lte(){return b},order(){return b},limit(){return b},range(){return b},
 is(){return b},not(){return b},or(){return b},filter(){return b},maybeSingle(){one=true;return b},single(){one=true;return b},insert(){return b},update(){return b},upsert(){return b},delete(){return b},
 then(res,rej){let d=T[table]||[];if(one)d=d[0]||null;return Promise.resolve({data:d,error:null,count:Array.isArray(d)?d.length:null}).then(res,rej)}};return b}
export function createClient(){return {auth:{getSession:async()=>({data:{session:{user:{id:'u1'}}},error:null}),getUser:async()=>({data:{user:{id:'u1',email:'ben@test.invalid'}},error:null}),
 onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}}},signOut:async()=>({error:null})},from:q,rpc:async()=>({data:[],error:null}),
 storage:{from:()=>({upload:async()=>({error:null}),getPublicUrl:()=>({data:{publicUrl:''}})})},channel(){const c={on(){return c},subscribe(){return c}};return c},removeChannel(){}}}`;
const mime={'.html':'text/html','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.woff':'font/woff','.png':'image/png','.webp':'image/webp'};
(async()=>{
 const server=http.createServer((req,res)=>{const rel=decodeURIComponent(new URL(req.url,'http://x').pathname).replace(/^\/+/,'')||'index.html';
  const file=path.join(root,rel);if(!file.startsWith(root)||!fs.existsSync(file)||fs.statSync(file).isDirectory()){res.writeHead(404);return res.end()}
  res.writeHead(200,{'content-type':mime[path.extname(file)]||'application/octet-stream'});fs.createReadStream(file).pipe(res)});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch();
 try{
  for(const viewport of [{width:390,height:844},{width:1240,height:900}]){
   const ctx=await browser.newContext({viewport});
   await ctx.route(/cdn\.jsdelivr\.net/,r=>r.fulfill({status:200,contentType:'text/javascript',headers:{'access-control-allow-origin':'*'},body:mock}));
   await ctx.route(/^https?:\/\/(?!127\.0\.0\.1)(?!cdn\.jsdelivr)/,r=>r.abort());
   const page=await ctx.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
   await page.goto('http://127.0.0.1:'+server.address().port+'/boxer.html');
   await page.locator('#content:not(.hidden)').waitFor();
   const field=page.locator('.tl-choice-field.is-grouped');await field.waitFor();
   const cards=()=>field.locator('.tl-choice-card').evaluateAll(list=>list.map(b=>b.querySelector('.tl-choice-copy').firstChild.textContent.trim()));
   const tab=name=>field.locator('.tl-choice-tab',{hasText:new RegExp('^'+name.replace(/[&]/g,'\\&')+'$')});
   // Zuerst eine Boxen-Art auswählen (typischer Zustand: zuletzt genutzte Art ist vorausgewählt).
   await tab('Boxen').click();await field.locator('.tl-choice-card',{hasText:'Reguläres Boxtraining'}).click();
   assert.equal(await page.$eval('#kind',s=>s.selectedOptions[0].textContent),'Reguläres Boxtraining');
   const expected={'Wettkampf':['Wettkampf','Trainingslager / Camp-Tag','Wettkampfsparring'],'Athletik':['Sprint-Intervalle','Krafttraining','Seilspringen / Konditionszirkel'],
    'Ausdauer':['Joggen','Alternative Ausdauer (Rad, Schwimmen, Rudern)'],'Erholung & Team':['Trainingsassistenz','Mobilität / Regeneration'],
    'Boxen':['Reguläres Boxtraining','Techniktraining','Pratzentraining','Sandsack / Rundenarbeit','Schattenboxen / Heimtraining']};
   for(const [name,list] of Object.entries(expected)){
    await tab(name).click();
    assert.equal(await tab(name).getAttribute('aria-selected'),'true',name+' muss aktiv werden ('+viewport.width+' px)');
    assert.deepEqual(await cards(),list,name+' zeigt seine Arten');
    assert.equal(await page.$eval('#kind',s=>s.selectedOptions[0].textContent),'Reguläres Boxtraining','Tab-Wechsel ändert die Auswahl nicht');
   }
   // Aus einem anderen Bereich wählen und wieder wechseln
   await tab('Erholung & Team').click();await field.locator('.tl-choice-card',{hasText:'Mobilität'}).click();
   assert.equal(await page.$eval('#kind',s=>s.selectedOptions[0].textContent),'Mobilität / Regeneration');
   await tab('Athletik').click();assert.deepEqual(await cards(),expected['Athletik']);
   // Wird die Auswahl von aussen gesetzt (Entwurf/letzte Art), springt die Ansicht zu ihrem Bereich.
   await page.$eval('#kind',s=>{s.value='6';s.dispatchEvent(new Event('change',{bubbles:true}))});
   assert.equal(await field.locator('.tl-choice-tab.is-active').textContent(),'Ausdauer');
   assert.deepEqual(errors,[],'keine JS-Fehler');
   await ctx.close();
  }
  console.log('PASS: alle Bereichs-Tasten anklickbar trotz vorausgewählter Art (390 und 1240 px); externe Auswahl springt zum Bereich');
 } finally {await browser.close();server.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
