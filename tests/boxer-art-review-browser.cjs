'use strict';
/* Isolated visual-review test: reads two local files, checks canvas resolution
 * and allows overlay comparison without any Supabase/session/network upload. */
const assert=require('node:assert/strict');
const fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const html=fs.readFileSync('tools/boxer-art-review.html','utf8');
assert.ok(html.includes('type="file"'),'reference and candidate stay local');
assert.ok(!/supabase|fetch\(|XMLHttpRequest|sendBeacon|WebSocket/i.test(html.split('<script>')[1]||''),
 'reviewer must never transfer image bytes to network');
const pixel=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO/uAKQAAAAASUVORK5CYII=','base64');
(async()=>{
 const server=http.createServer((req,res)=>{
  if(req.url!=='/tools/boxer-art-review.html'){res.writeHead(404);res.end();return}
  res.setHeader('Content-Type','text/html; charset=utf-8');res.end(html);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 let browser;
 try{
  browser=await chromium.launch({headless:true,args:['--no-sandbox']});
  const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:1});
  await page.goto('http://127.0.0.1:'+server.address().port+'/tools/boxer-art-review.html');
  await page.locator('#reference').setInputFiles({name:'crossed-arms.png',mimeType:'image/png',buffer:pixel});
  await page.locator('#candidate').setInputFiles({name:'new-anime.png',mimeType:'image/png',buffer:pixel});
  await page.waitForFunction(()=>document.querySelector('#candidateImage').hidden===false);
  assert.match(await page.locator('#candidateState').textContent(),/1 × 1 px/,'file check reports wrong dimension');
  assert.equal(await page.locator('#overlayPanel').isHidden(),true,'comparison is initially opt-in');
  await page.click('#switch');
  assert.equal(await page.locator('#overlayPanel').isVisible(),true,'two source images can be compared');
  await page.locator('#compare').evaluate(el=>{el.value='72';el.dispatchEvent(new Event('input',{bubbles:true}))});
  assert.equal(await page.locator('#percent').textContent(),'72 %');
  assert.equal(await page.locator('#split').evaluate(e=>e.style.width),'72%');
  await page.click('#checker');
  assert.equal(await page.locator('#candidateStage').evaluate(e=>e.classList.contains('checkers')),true);
  assert.equal(await page.locator('#overlayStage').evaluate(e=>e.classList.contains('checkers')),true);
  await page.setViewportSize({width:375,height:667});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),
   'reviewer does not overflow the screen horizontally on a narrow phone');
  await page.close();
  console.log('PASS: local anime art reviewer, file checks, split comparison, mobile layout');
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r))}
})().catch(e=>{console.error(e);process.exitCode=1});