'use strict';
// Chromium test (mocked Supabase, no server writes) for Etappe 18: Admin gibt Bonus-EXP im Kampfgeist-Shop → Verwaltung → Bonus-EXP,
// wahlweise mit Monatspunkten, Vorlagen für Betrag und Grund, Liste der letzten Boni und Rücknahme mit Grund. Basis: kampfgeist-browser.cjs.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const src=fs.readFileSync(path.join(__dirname,'kampfgeist-browser.cjs'),'utf8');
const sql=fs.readFileSync('supabase/migrations/20261028210000_kampfgeist_shop.sql','utf8');
const unq=s=>s==='NULL'?null:s.slice(1,-1).replace(/''/g,"'");
const ITEMS=[...sql.matchAll(/\('([a-z0-9_]+)','(avatar|aura|banner|rahmen|titel|handschuhe)','((?:[^']|'')*)',(NULL|'(?:[^']|'')*'),'(\w+)','([FEDCBAS])','(start|rank|shop)',(NULL|\d+),'(\{[^']*\})',(\d+)\)/g)]
 .map(m=>({key:m[1],category:m[2],name:m[3].replace(/''/g,"'"),description:unq(m[4]),rarity:m[5],min_rank:m[6],unlock:m[7],price:m[8]==='NULL'?null:+m[8],design:JSON.parse(m[9]),sort:+m[10]}));
let inj=src.slice(src.indexOf('function injected(cfg){'),src.indexOf('\n}\n',src.indexOf('function injected(cfg){'))+2);
const hook="   case 'admin_adjust_coins':";
assert.ok(inj.includes(hook),'mock hook');
inj=inj.replace(hook,`   case 'admin_list_bonuses':return {data:(window.__bonuses=window.__bonuses||[{id:'tx-old',display_name:'Anna',exp:25,points:25,reason:'Feedbackvideo',date:'2026-10-15',revoked:false}]),error:null};
   case 'admin_give_bonus':{const b={id:'tx-new',display_name:'Anna',exp:args.p_exp,points:args.p_with_points?args.p_exp:0,reason:args.p_reason.trim(),date:'2026-10-29',revoked:false};window.__bonuses=[b,...(window.__bonuses||[])];return {data:{id:b.id,display_name:'Anna',exp:b.exp,points:b.points,reason:b.reason},error:null}}
   case 'admin_revoke_bonus':{const b=(window.__bonuses||[]).find(x=>x.id===args.p_tx_id);b.revoked=true;b.revoke_reason=args.p_reason;return {data:{id:b.id,exp:-b.exp,points:-b.points},error:null}}
`+hook);
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const context=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
 await context.addInitScript({content:'('+inj+')('+JSON.stringify({role:'admin',items:ITEMS,balance:230,exp:1010,level:7,rankIdx:0})+')'});
 const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));p.on('dialog',d=>{errors.push('dialog');d.dismiss()});
 await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
 await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
 await p.goto(base+'shop.html');
 await p.waitForSelector('[data-tab="admin"]');await p.click('[data-tab="admin"]');
 // Aus «Konten»: Bonus-EXP für Anna (nicht für den Admin selbst)
 await p.waitForSelector('[data-bonusfor="p-anna"]');
 assert.equal(await p.locator('[data-bonusfor="p-admin"]').count(),0,'no bonus for own admin account');
 await p.click('[data-bonusfor="p-anna"]');
 await p.waitForSelector('#bonusForm');
 assert.equal(await p.inputValue('#bonusForm [name="who"]'),'p-anna','boxer preselected');
 assert.equal(await p.locator('#bonusForm [name="who"] option[value="p-admin"]').count(),0);
 await p.waitForFunction(()=>/Feedbackvideo/.test(document.querySelector('.tlp-list')?.textContent||''));
 // Vorlagen: 25 EXP, «Feedbackvideo geschickt», nur EXP
 await p.click('[data-bexp="25"]');await p.click('[data-breason="Feedbackvideo geschickt"]');
 assert.equal(await p.inputValue('#bonusForm [name="exp"]'),'25');assert.equal(await p.inputValue('#bonusForm [name="reason"]'),'Feedbackvideo geschickt');
 await p.click('#bonusForm button[type="submit"]');
 await p.waitForFunction(()=>/Bonus gegeben: \+25 EXP für Anna/.test(document.getElementById('status').textContent));
 let call=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='admin_give_bonus')[1];
 assert.deepEqual(call,{p_profile_id:'p-anna',p_exp:25,p_with_points:false,p_reason:'Feedbackvideo geschickt'});
 assert.doesNotMatch(await p.textContent('#status'),/Punkte/);
 // Mit Monatspunkten
 await p.selectOption('#bonusForm [name="who"]','p-anna');await p.fill('#bonusForm [name="exp"]','40');await p.check('#bonusForm [name="pts"]');
 await p.fill('#bonusForm [name="reason"]','Speziell aufgefallen');await p.click('#bonusForm button[type="submit"]');
 await p.waitForFunction(()=>/\+40 EXP und \+40 Punkte/.test(document.getElementById('status').textContent));
 call=(await p.evaluate(()=>window.__calls)).filter(c=>c[0]==='admin_give_bonus').pop()[1];assert.equal(call.p_with_points,true);
 assert.match(await p.textContent('.tlp-list'),/Anna\s*\+40 EXP · \+40 Punkte[\s\S]*Speziell aufgefallen/);
 // Rücknahme mit Grund (nicht ohne)
 const first=p.locator('.tlp-list .tlp-li').first();
 await first.locator('summary').click();
 await first.locator('form.kg-brevoke button').click();await p.waitForTimeout(200);
 assert.ok(!(await p.evaluate(()=>window.__calls)).some(c=>c[0]==='admin_revoke_bonus'),'no revoke without reason');
 await first.locator('form.kg-brevoke [name="reason"]').fill('Falscher Boxer');await first.locator('form.kg-brevoke button').click();
 await p.waitForFunction(()=>/Bonus zurückgenommen: -40 EXP, -40 Punkte/.test(document.getElementById('status').textContent));
 assert.equal(await p.locator('.tlp-list .tlp-li:first-child.kg-revoked').count(),1);
 assert.match(await p.textContent('.tlp-list .tlp-li:first-child'),/zurückgenommen[\s\S]*Falscher Boxer/);
 assert.equal(await p.locator('.tlp-list .tlp-li:first-child form.kg-brevoke').count(),0);
 const chips=await p.evaluate(()=>[...document.querySelectorAll('[data-breason]')].every(b=>{const r=b.getBoundingClientRect();return r.right<=innerWidth&&r.left>=0}));
 assert.ok(chips,'reason chips wrap inside the screen');
 if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/18-bonus.png',fullPage:true});
 assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');
 assert.deepEqual(errors,[]);
 await context.close();await browser.close();server.close();
 console.log('PASS: Etappe 18 im Browser – Bonus-EXP aus «Konten» vorgewählt (nicht für den Admin), Vorlagen für Betrag und Grund, nur EXP oder mit Punkten, Liste, Rücknahme nur mit Grund');
})().catch(e=>{console.error(e);process.exit(1)});
