'use strict';
/* Real staff pages in Chromium, mocked authentication/data.
 * Tests layout, functional tabs, searchable pagination and role barriers.
 * No production accounts, no mutations against live Supabase.
 */
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const trainingSource=fs.readFileSync(path.join(root,'tests/training-v2-browser.cjs'),'utf8');
const injStart=trainingSource.indexOf('function injected(cfg){');
const injEnd=trainingSource.indexOf('\n}\nconst shotsDir',injStart);
assert.ok(injStart>=0&&injEnd>injStart,'existing training mock injection available');
const injectCoach=new Function(trainingSource.slice(injStart,injEnd+2)+'\nreturn injected;')();
const mockAdmin=String.raw`
export function createClient(){
 const requestedRole=new URLSearchParams(location.search).get('role')||'admin';
 const me={id:'auth-admin',email:'admin@test.invalid'};
 const profiles=[{id:'owner',display_name:'Owner',role:'admin',is_active:true,is_listed:true,has_account:true,email:'owner@test.invalid',created_at:'2026-01-01'}];
 for(let i=1;i<=14;i++)profiles.push({id:'boxer-'+i,display_name:'Boxer '+String(i).padStart(2,'0'),role:'boxer',
  is_active:true,is_listed:i%2===0,has_account:true,email:'boxer'+i+'@test.invalid',created_at:'2026-01-01'});
 function query(table){
  let filters=[];const q={
   select(){return q},eq(k,v){filters.push([k,v]);return q},
   maybeSingle:async()=>({data:{id:'owner',role:requestedRole,is_active:true},error:null}),
   order(){return q},limit(){return q},
   then(resolve,reject){return Promise.resolve({data:table==='profile_admin_audit'?[]:[],error:null}).then(resolve,reject)}
  };return q;
 }
 return {
  auth:{getUser:async()=>({data:{user:me},error:null}),getSession:async()=>({data:{session:{access_token:'test'}},error:null})},
  from:query,rpc:async name=>{
   if(requestedRole!=='admin')return {error:{message:'Not authorized'},data:null};
   if(name==='admin_list_profiles')return {data:profiles,error:null};
   if(name==='admin_list_profile_archive_state')return {data:[],error:null};
   return {data:null,error:null};
  }
 };
}`;
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml','.woff':'font/woff','.png':'image/png'};
const server=http.createServer((req,res)=>{
 const rel=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\/+/,'')||'index.html';
 const file=path.resolve(root,rel);
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,bytes)=>{if(err){res.writeHead(404);res.end();return}res.setHeader('content-type',mime[path.extname(file)]||'application/octet-stream');res.end(bytes)});
});
const shotDir=process.env.STAFF_SHOTS;
async function shot(page,name){if(!shotDir)return;fs.mkdirSync(shotDir,{recursive:true});await page.screenshot({path:path.join(shotDir,name+'.png')})}
async function adminScenario(browser,base,width){
 const ctx=await browser.newContext({viewport:{width,height:844},locale:'de-CH'});
 const page=await ctx.newPage();
 page.on('dialog',d=>d.accept());
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.route(/^https:\/\/(?!127\.0\.0\.1)/,r=>r.abort());
 await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',headers:{'access-control-allow-origin':'*'},body:mockAdmin}));
 await page.goto(base+'/admin.html');
 await page.locator('#profilesBody tr').first().waitFor();
 assert.equal(await page.locator('#profilesBody tr').count(),10,'admin starts at ten results');
 assert.ok(await page.locator('[data-staff-more]').isVisible(),'pagination reachable');
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),'admin no viewport overflow '+width);
 if(width<=390){
  const ribbon=await page.locator('.tl-screen-ribbon').boundingBox();
  const hero=await page.locator('.stf-admin-hero').boundingBox();
  const menu=await page.locator('.tl-screen-ribbon [data-stf-global-menu]').boundingBox();
  assert.ok(ribbon&&ribbon.height<=68,'admin mobile ribbon must be one compact row, got '+ribbon?.height);
  assert.ok(hero&&hero.height<=60,'admin mobile hero must be condensed, got '+hero?.height);
  assert.ok(menu&&menu.width>=44&&menu.height>=44,'admin global menu remains touch accessible');
 }
 await shot(page,'admin-boxer-'+width);
 await page.locator('[data-staff-more]').click();
 assert.equal(await page.locator('#profilesBody tr').count(),15,'more reveals rest of loaded profiles');
 await page.locator('[data-staff-search]').fill('Boxer 12');
 assert.equal(await page.locator('#profilesBody tr').count(),1,'search filters profile list');
 assert.match(await page.locator('#profilesBody tr').first().textContent(),/Boxer 12/);
 await page.locator('[data-staff-target="security"]').click();
 assert.ok(await page.locator('[data-staff-pane="profiles"]').isHidden());
 assert.ok(await page.locator('[data-staff-pane="security"]').isVisible());
 await page.locator('[data-staff-target="audit"]').click();
 assert.ok(await page.locator('[data-staff-pane="audit"]').isVisible());
 await page.locator('[data-staff-target="profiles"]').click();
 assert.ok(await page.locator('[data-staff-pane="profiles"]').isVisible());
 const menu=page.locator('.stf-admin-tabs [data-stf-global-menu]');
 await menu.click();
 await page.locator('#tl-menu-panel[aria-hidden="false"]').waitFor();
 await page.keyboard.press('Escape');
 assert.deepEqual(errors,[]);
 await ctx.close();
 const denied=await browser.newContext({viewport:{width:390,height:844}});
 const forbidden=await denied.newPage();
 await forbidden.route(/^https:\/\/(?!127\.0\.0\.1)/,r=>r.abort());
 await forbidden.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',headers:{'access-control-allow-origin':'*'},body:mockAdmin}));
 await forbidden.goto(base+'/admin.html?role=coach');
 await forbidden.waitForFunction(()=>/Zugriff verweigert/.test(document.querySelector('#adminStatus')?.textContent||''));
 assert.ok(await forbidden.locator('#adminContent').isHidden(),'non-admin cannot access admin panels');
 await denied.close();
}
async function coachScenario(browser,base,width){
 const ctx=await browser.newContext({viewport:{width,height:844},locale:'de-CH',timezoneId:'Europe/Zurich'});
 await ctx.addInitScript({content:'('+injectCoach.toString()+')({role:"coach",v2:true})'});
 const page=await ctx.newPage();page.on('dialog',d=>d.accept());
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.route(/^https:\/\/(?!127\.0\.0\.1)/,r=>r.abort());
 await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
 await page.goto(base+'/coach.html');
 await page.locator('#cv2Tabs [data-view="review"]').waitFor();
 assert.ok(await page.locator('.tl-screen-ribbon').isVisible(),'premium trainer topbar visible');
 assert.equal(await page.locator('#cv2Tabs [data-view]').count(),6,'six live trainer views retained');
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),'coach no viewport overflow '+width);
 if(width<=390){
  const ribbon=await page.locator('.tl-screen-ribbon').boundingBox();
  const hero=await page.locator('.cv2-hero').boundingBox();
  const menu=await page.locator('.tl-screen-ribbon [data-stf-global-menu]').boundingBox();
  assert.ok(ribbon&&ribbon.height<=68,'coach mobile ribbon must be one compact row, got '+ribbon?.height);
  assert.ok(hero&&hero.height<=76,'coach mobile hero must be condensed, got '+hero?.height);
  assert.ok(menu&&menu.width>=44&&menu.height>=44,'coach global menu remains touch accessible');
 }
 if(width<900){
  const nav=await page.locator('#cv2Tabs').boundingBox();
  assert.ok(nav&&nav.y>620,'coach mobile dock remains at bottom');
 }
 await shot(page,'coach-start-'+width);
 await page.locator('#cv2Tabs [data-view="review"]').click();
 await page.locator('#viewReview').waitFor({state:'visible'});
 await shot(page,'coach-review-'+width);
 await page.locator('#cv2Tabs [data-view="boxers"]').click();
 await page.locator('#viewBoxers').waitFor({state:'visible'});
 await page.locator('[data-stf-global-menu]').first().click();
 await page.locator('#tl-menu-panel[aria-hidden="false"]').waitFor();
 await page.keyboard.press('Escape');
 assert.deepEqual(errors.filter(x=>!/Gamification|takeover-gamification/.test(x)),[]);
 await ctx.close();
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({headless:true});
 try{
  for(const width of [320,390,1366]){
   await adminScenario(browser,base,width);
   await coachScenario(browser,base,width);
  }
  console.log('PASS: real coach/admin UI 320/390/1366, role protection, navigation, 10-row profile paging, search and menu');
 }finally{await browser.close();server.close()}
})().catch(e=>{console.error(e);server.close();process.exitCode=1});
