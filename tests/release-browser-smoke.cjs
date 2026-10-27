'use strict';
// Actual Chromium smoke tests; network calls to public read-only Supabase RPCs
// are intercepted with deterministic fixtures. NO production writes or auth.
const assert=require('node:assert/strict');
const {chromium}=require('playwright');
const fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const root=process.cwd();
const type={'html':'text/html; charset=utf-8','js':'text/javascript; charset=utf-8','css':'text/css','png':'image/png','webp':'image/webp','webmanifest':'application/manifest+json'};
const server=http.createServer((req,res)=>{
 const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
 const relative=pathname==='/'?'index.html':pathname.slice(1);
 const resolved=path.resolve(root,relative);
 if(!resolved.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(resolved,(err,body)=>{if(err){res.writeHead(404);res.end('Not found');return}
  res.writeHead(200,{'content-type':type[path.extname(resolved).slice(1)]||'application/octet-stream'});res.end(body);
 });
});
async function main(){
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try{
 const leader=[
  {boxer_name:'Boxer Alpha',rank_position:1,monthly_points:140,lifetime_exp:420,approved_sessions:3,points_training:140,points_bonus:0},
  {boxer_name:'Boxer Beta',rank_position:2,monthly_points:60,lifetime_exp:240,approved_sessions:2,points_training:60,points_bonus:0}
 ];
 const levels=[{boxer_name:'Boxer Alpha',lifetime_exp:420},{boxer_name:'Boxer Beta',lifetime_exp:240}];
 for(const width of [375,768,1280]){
  const context=await browser.newContext({viewport:{width,height:800},isMobile:width===375,hasTouch:width===375});
  const page=await context.newPage();page.setDefaultTimeout(10000);
  await page.route('**/rest/v1/rpc/**', async route=>{
   const fn=route.request().url().split('/').pop();
   const data=fn==='get_public_levels'?levels:fn==='get_public_leaderboard'?leader:fn==='get_public_boxer_avatars'?[]:[];
   await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  });
  await page.goto(base+'boxer-compare.html',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>document.querySelector('#chooser').hidden===false);
  await page.selectOption('#left','Boxer Alpha');
  await page.selectOption('#right','Boxer Beta');
  assert.equal(await page.locator('#results article').count(),2,'Two boxers compared');
  assert.match(await page.locator('#results').innerText(),/140/,'Public monthly points visible');
  await page.locator('#results button').first().click();
  assert.match(await page.locator('#favorites').innerText(),/Alpha/);
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  assert.ok(overflow<=4,'Unexpected horizontal overflow in compare at '+width+': '+overflow);
  await page.goto(base+'boxer-profile.html?name=Boxer%20Alpha',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>document.getElementById('profileCard')?.hidden===false);
  // The Fight-Night design shows names in capitals (CSS text-transform); compare the real text.
  assert.match(await page.locator('#profileName').textContent(),/Boxer Alpha/);
  assert.match(await page.locator('#compareAction').getAttribute('href'),/boxer-compare.html/);
  await page.locator('#takeover-menu-open').click();
  assert.equal(await page.locator('#tl-menu-panel').getAttribute('aria-hidden'),'false');
  await page.keyboard.press('Escape');
  assert.equal(await page.locator('#tl-menu-panel').getAttribute('aria-hidden'),'true');
  const b=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  assert.ok(b<=4,'Unexpected profile horizontal overflow at '+width+': '+b);
  await context.close();
  console.log('PASS public profile/compare/menu/mobile viewport '+width);
 }
 }finally{await browser.close()}
}
// Always close the browser and exit: a failed assertion must fail fast instead of hanging the CI job.
main().then(()=>server.close()).catch(e=>{console.error('BROWSER SMOKE FAILED',e);server.close();process.exit(1)});
