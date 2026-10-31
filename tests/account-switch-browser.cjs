// Konto-Umschalter (27.10.2026): Admin und Boxerkonto im selben Browser, Wechsel ohne Ummelden.
// Der Supabase-Mock speichert die Sitzung wie supabase-js unter sb-<ref>-auth-token im localStorage.
const {chromium}=require('playwright');
const http=require('node:http');const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
const root=path.join(__dirname,'..');
const KEY='sb-iqarjivcrddcixrvqbfb-auth-token';
const mock=`
const KEY='${KEY}';
const users={'admin@test.invalid':{id:'u-admin',email:'admin@test.invalid'},'ben@test.invalid':{id:'u-ben',email:'ben@test.invalid'}};
const profiles=[{id:'p-admin',auth_user_id:'u-admin',display_name:'Bendo',role:'admin',is_active:true,is_listed:true},
 {id:'p-ben',auth_user_id:'u-ben',display_name:'Ben',role:'boxer',is_active:true,is_listed:true}];
const read=()=>{try{return JSON.parse(localStorage.getItem(KEY)||'null')}catch{return null}};
function query(table){let filters=[],one=false;const b={select(){return b},eq(k,v){filters.push([k,v]);return b},neq(){return b},in(){return b},gte(){return b},lte(){return b},
 order(){return b},limit(){return b},range(){return b},is(){return b},not(){return b},or(){return b},filter(){return b},ilike(){return b},
 maybeSingle(){one=true;return b},single(){one=true;return b},insert(){return b},update(){return b},upsert(){return b},delete(){return b},
 then(res,rej){let rows=table==='profiles'?profiles.filter(r=>filters.every(([k,v])=>r[k]===v)):[];const data=one?(rows[0]||null):rows;
  return Promise.resolve({data,error:null,count:Array.isArray(data)?data.length:null}).then(res,rej)}};return b}
export function createClient(){
 const listeners=[];
 return {auth:{
  getSession:async()=>({data:{session:read()},error:null}),
  getUser:async()=>{const s=read();return s?{data:{user:s.user},error:null}:{data:{user:null},error:{message:'no session'}}},
  signInWithPassword:async({email})=>{localStorage.removeItem(KEY);const user=users[email];if(!user)return {error:{message:'Invalid login'}};
   localStorage.setItem(KEY,JSON.stringify({access_token:'at-'+user.id,refresh_token:'rt-'+user.id+'-'+Math.random(),user}));return {data:{user},error:null}},
  signOut:async()=>{localStorage.removeItem(KEY);listeners.forEach(cb=>cb('SIGNED_OUT',null));return {error:null}},
  onAuthStateChange:cb=>{listeners.push(cb);return {data:{subscription:{unsubscribe(){}}}}},
  resetPasswordForEmail:async()=>({error:null}),updateUser:async()=>({error:null}),signUp:async()=>({data:{},error:null})},
 from:query,rpc:async()=>({data:[],error:null}),storage:{from:()=>({upload:async()=>({error:null}),getPublicUrl:()=>({data:{publicUrl:''}})})},
 channel(){const c={on(){return c},subscribe(){return c}};return c},removeChannel(){},removeAllChannels(){}};
}`;
const mime={'.html':'text/html','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.woff':'font/woff','.png':'image/png'};
(async()=>{
 const server=http.createServer((req,res)=>{const rel=decodeURIComponent(new URL(req.url,'http://x').pathname).replace(/^\/+/,'')||'index.html';
  const file=path.join(root,rel);if(!file.startsWith(root)||!fs.existsSync(file)||fs.statSync(file).isDirectory()){res.writeHead(404);return res.end()}
  res.writeHead(200,{'content-type':mime[path.extname(file)]||'application/octet-stream'});fs.createReadStream(file).pipe(res)});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch();
 try{
  const ctx=await browser.newContext({viewport:{width:390,height:844}});
  await ctx.route(/cdn\.jsdelivr\.net/,r=>r.fulfill({status:200,contentType:'text/javascript',headers:{'access-control-allow-origin':'*'},body:mock}));
  await ctx.route(/^https?:\/\/(?!127\.0\.0\.1)(?!cdn\.jsdelivr)/,r=>r.abort());
  const page=await ctx.newPage();page.on('dialog',d=>d.accept());
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const accounts=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('takeover_accounts_v1')||'[]').map(a=>a.name+':'+a.role));
  const openMenu=async()=>{await page.locator('#takeover-menu-open').click();await page.locator('.tl-account-switch').waitFor()};
  // 1) Admin angemeldet → Navigation merkt sich das Konto
  await page.goto(base+'/login.html');
  await page.fill('#email','admin@test.invalid');await page.fill('#password','x');await page.click('#loginBtn');
  await page.waitForURL(/coach\.html/);
  await page.goto(base+'/index.html');await openMenu();
  assert.match(await page.locator('.tl-account-current').textContent(),/Angemeldet als Bendo \(Admin\)/);
  assert.deepEqual(await accounts(),['Bendo:admin']);
  // 2) Weiteres Konto hinzufügen, ohne das Admin-Konto zu verlieren
  await page.click('.tl-account-add');await page.waitForURL(/login\.html\?add=1/);
  await page.locator('#loginView:not(.hide)').waitFor();
  assert.match(await page.locator('#message').textContent(),/Weiteres Konto hinzufügen/);
  await page.fill('#email','ben@test.invalid');await page.fill('#password','x');await page.click('#loginBtn');
  await page.waitForURL(/boxer-experience\.html/);
  // Public league with an explicit hash stays accessible to boxers.
  // Without a hash, the app opens the new Boxer Experience.
  await page.goto(base+'/index.html#ranking');await openMenu();
  assert.match(await page.locator('.tl-account-current').textContent(),/Angemeldet als Ben \(Boxer\)/);
  assert.deepEqual((await accounts()).sort(),['Ben:boxer','Bendo:admin']);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=390),true,'Menü mit Konten ohne horizontalen Scroll');
  // 3) Per Tipp zurück zum Admin – ohne Passwort
  await page.getByRole('button',{name:/Wechseln zu Bendo \(Admin\)/}).click();
  await page.waitForURL(/admin\.html/);
  assert.equal(await page.evaluate(k=>JSON.parse(localStorage.getItem(k)).user.id,KEY),'u-admin');
  await page.goto(base+'/index.html');await openMenu();
  assert.match(await page.locator('.tl-account-current').textContent(),/Bendo \(Admin\)/);
  await page.getByRole('button',{name:/Wechseln zu Ben \(Boxer\)/}).waitFor();
  // 4) Abmelden entfernt nur das aktuelle Konto aus dem Umschalter
  await page.goto(base+'/login.html');await page.locator('#accountView:not(.hide)').waitFor();
  await page.click('#logoutBtn');await page.locator('#loginView:not(.hide)').waitFor();
  assert.deepEqual(await accounts(),['Ben:boxer']);
  // 5) Entfernen-Knopf
  await page.goto(base+'/index.html');await page.locator('#takeover-menu-open').click();await page.locator('.tl-account-forget').first().click();
  assert.deepEqual(await accounts(),[]);
  assert.deepEqual(errors,[],'keine JS-Fehler');
  console.log('PASS: Konto-Umschalter – merken, hinzufügen ohne Verlust, Wechsel ohne Passwort, Abmelden/Entfernen, 390 px');
 } finally {await browser.close();server.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
