// Konto-Umschalter (Takeover 3.0, «Mein Account» oben rechts): Admin und Boxerkonto im selben Browser, Wechsel ohne Ummelden.
// Ausführliche Fälle (abgelaufene Sitzung, Rollenwechsel, Migration, PWA-Neustart) prüft tests/takeover3-browser.cjs.
const {chromium}=require('playwright');const assert=require('node:assert/strict');
const H=require('./takeover3-harness.cjs');
const config=`{users:[{id:'u-admin',email:'admin@test.invalid'},{id:'u-ben',email:'ben@test.invalid'}],
 tables:{profiles:[{id:'p-admin',auth_user_id:'u-admin',display_name:'Bendo',role:'admin',is_active:true,is_listed:true},
  {id:'p-ben',auth_user_id:'u-ben',display_name:'Ben',role:'boxer',is_active:true,is_listed:true}]},rpc:{get_public_leaderboard:[]}}`;
(async()=>{
 const {server,base}=await H.serve();const browser=await chromium.launch();
 try{
  const ctx=await H.context(browser,{config});const page=await ctx.newPage();page.on('dialog',d=>d.accept());
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const accounts=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('takeover_accounts_v2')||'[]').map(a=>a.name+':'+a.role));
  const user=()=>page.evaluate(k=>JSON.parse(localStorage.getItem(k)||'null')?.user?.id||null,H.KEY);
  const openMenu=async()=>{await page.locator('#tla-account-btn, #ex-settings').first().click();await page.locator('#tla-drawer:not([hidden]) .tla-account').waitFor()};
  // 1) Admin angemeldet → Clubverwaltung, Konto gemerkt
  await page.goto(base+'/login.html');await page.fill('#email','admin@test.invalid');await page.fill('#password','pw');await page.click('#loginBtn');
  await page.waitForURL(/admin\.html/);await openMenu();
  assert.match(await page.locator('.tla-current').innerText(),/Bendo/i);
  assert.deepEqual(await accounts(),['Bendo:admin']);
  // 2) Weiteres Konto hinzufügen, ohne das Admin-Konto zu verlieren
  await page.click('.tla-action:has-text("Weiteres Konto")');await page.waitForURL(/login\.html\?add=1/);
  await page.locator('#loginView:not(.hide)').waitFor();
  assert.match(await page.locator('#message').textContent(),/Weiteres Konto hinzufügen/);
  await page.fill('#email','ben@test.invalid');await page.fill('#password','pw');await page.click('#loginBtn');
  await page.waitForURL(/boxer-experience\.html/);
  assert.deepEqual((await accounts()).sort(),['Ben:boxer','Bendo:admin']);
  // 3) Wechsel zum Admin → Clubverwaltung, zurück zum Boxer → Boxer Experience (nicht das alte Studio)
  await openMenu();await page.click('.tla-switch:has-text("Bendo")');await page.waitForURL(/admin\.html/);assert.equal(await user(),'u-admin');
  await openMenu();await page.click('.tla-switch:has-text("Ben")');await page.waitForURL(/boxer-experience\.html/);assert.equal(await user(),'u-ben');
  // 4) Abmelden entfernt nur das aktuelle Konto
  await openMenu();await page.click('.tla-logout');await page.waitForURL(/login\.html$/);
  assert.equal(await user(),null);assert.deepEqual(await accounts(),['Bendo:admin']);
  // 5) Entfernen
  await page.goto(base+'/index.html#ranking');await openMenu();await page.click('.tla-remove');assert.deepEqual(await accounts(),[]);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1),'no horizontal scroll at 390px');
  assert.deepEqual(errors,[]);
  console.log('account-switch-browser: ok');
 }finally{await browser.close();server.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
