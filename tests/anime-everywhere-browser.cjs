'use strict';
// Anime-Darstellung überall: In der veröffentlichten Seite (gleicher Build wie GitHub Pages) zeigen das eigene Holo,
// das Podium und die FUT-Card in «Mein Takeover» die Anime-Grafik des Editors statt des SVG-Fallbacks.
// Auch Jab verwendet die gemeinsame Anime-Pipeline. Kontodaten sind simuliert.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http');
const pw=require('playwright');const H=require('./takeover3-harness.cjs');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css','.json':'application/json','.png':'image/png','.webp':'image/webp','.svg':'image/svg+xml','.woff':'font/woff'};
const config=`{users:[{id:'u-ben',email:'ben@test.invalid'}],
 tables:{profiles:[{id:'p-ben',auth_user_id:'u-ben',display_name:'Ben',role:'boxer',is_active:true}],league_feature_flags:[{feature_key:'performance_dashboard',is_enabled:true}],training_types:[]},
 rpc:{get_public_leaderboard:[{rank_position:1,boxer_name:'Anna',monthly_points:900},{rank_position:2,boxer_name:'Ben',monthly_points:700},{rank_position:3,boxer_name:'Cleo',monthly_points:500}],
  get_holo_looks:a=>({data:Object.fromEntries((a.p_display_names||[]).map(n=>[n,n==='Cleo'?{pose_profile:'jab'}:{pose_profile:'guard',pose_card:'guard'}])),error:null}),
  get_card_looks:{},get_my_feedback:{enabled:false},league_training_audit_recent:[],
  get_my_performance:{rating:{current:{summary:{overall:80,categories:{OFF:80,DEF:78,BEI:82,KON:79,TAK:81,MEN:80}}}}},
  get_boxer_exp_level_rank:[{lifetime_exp:500,lifetime_points:500}],get_training_v2_config:{enabled:false}}}`;
(async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'anime-everywhere-'));
 const report=require('../tools/assemble-pages-site.cjs').assemble(process.cwd(),dir);
 assert.ok(report.premium.enabled,'premium release enabled');
 const server=http.createServer((req,res)=>{const file=path.resolve(dir,'.'+decodeURIComponent(new URL(req.url,'http://x').pathname));
  if(!file.startsWith(dir+path.sep)||!fs.existsSync(file)||fs.statSync(file).isDirectory()){res.writeHead(404);return res.end()}
  res.writeHead(200,{'content-type':mime[path.extname(file)]||'application/octet-stream'});fs.createReadStream(file).pipe(res)});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 const engines=[['chromium',pw.chromium]];try{const b=await pw.webkit.launch();await b.close();engines.push(['webkit',pw.webkit])}catch(_){console.log('WebKit nicht installiert – nur Chromium')}
 try{for(const [name,engine] of engines){
  const browser=await engine.launch();
  try{
   const ctx=await H.context(browser,{config});const page=await ctx.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
   await page.goto(base+'/login.html');await page.fill('#email','ben@test.invalid');await page.fill('#password','pw');await page.click('#loginBtn');
   await page.waitForURL(/boxer-experience\.html/);await page.locator('#ex-app:not([hidden])').waitFor();
   // Eigenes Holo auf «Heute»
   await page.locator('#ex-home-holo svg.tlh-anime image').waitFor({timeout:90000});
   assert.match(await page.locator('#ex-home-holo svg.tlh-anime image').getAttribute('href'),/^data:image\/png;base64,/);
   // Podium: Guard und Jab verwenden beide Anime.
   await page.click('.ex-menu [data-tab="liga"]');
   await page.waitForFunction(()=>document.querySelectorAll('#ex-podium svg.tlh-anime').length===3,null,{timeout:90000});
   assert.equal(await page.locator('#ex-podium svg.tlh:not(.tlh-anime)').count(),0,'all registered poses use Anime');
   // FUT-Card in «Mein Boxer»
   await page.click('.ex-menu [data-tab="boxer"]');
   await page.locator('#ex-fut-card .tlp-holo svg.tlh-anime image').waitFor({timeout:90000});
   if(process.env.SHOTS){fs.mkdirSync(process.env.SHOTS,{recursive:true});await page.screenshot({path:path.join(process.env.SHOTS,name+'-anime-fut.png')});
    await page.click('.ex-menu [data-tab="heute"]');await page.screenshot({path:path.join(process.env.SHOTS,name+'-anime-heute.png')})}
   assert.deepEqual(errors,[]);await ctx.close();
   console.log('PASS '+name+': Anime auf Heute, Podium und FUT-Card; Jab ebenfalls Anime');
  }finally{await browser.close()}
 }}finally{server.close();fs.rmSync(dir,{recursive:true,force:true})}
})().catch(e=>{console.error(e);process.exitCode=1});
