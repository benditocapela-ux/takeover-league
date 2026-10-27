'use strict';
const {chromium}=require('playwright'),http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=process.cwd(),mime={'.html':'text/html','.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml'};
const mockModule=`
export function createClient(){
 const user={id:'test-admin-auth',email:'admin@test.invalid'};
 const role=new URLSearchParams(location.search).get('role')||'admin';
 const profiles=[
 {id:'1',display_name:'Eigentümer',role:'admin',is_active:true,is_listed:true,has_account:true,email:'admin@test.invalid',created_at:'2026-01-01'},
 {id:'2',display_name:'Neu angemeldeter Boxer',role:'boxer',is_active:true,is_listed:false,has_account:true,email:'new@test.invalid',created_at:'2026-10-19'},
 {id:'3',display_name:'Coach mit Zugang',role:'coach',is_active:true,is_listed:true,has_account:true,email:'coach@test.invalid',created_at:'2026-10-19'},
 {id:'4',display_name:'Vorbereitetes Profil',role:'boxer',is_active:false,is_listed:true,has_account:false,email:null,created_at:'2026-10-19'},
 {id:'5',display_name:'Altes Profil',role:'boxer',is_active:false,is_listed:false,has_account:false,email:null,created_at:'2026-09-01'}
 ];
 const from=table=>({
   select:()=>({
     eq:()=>({maybeSingle:async()=>({data:{id:'1',role,is_active:true},error:null})}),
     order:()=>({limit:async()=>({data:[],error:null})})
   })
 });
 return {
   auth:{getSession:async()=>({data:{session:{access_token:'test'}},error:null}),
         getUser:async()=>({data:{user},error:null})},
   from,
   rpc:async(fn,params)=>{
     if(role!=='admin')return {error:{message:'Nicht erlaubt'},data:null};
     if(fn==='admin_list_profiles')return {data:profiles,error:null};
     if(fn==='admin_list_profile_archive_state')return {data:[{profile_id:'5',archived_at:'2026-10-01T00:00:00Z'}],error:null};
     const id=params?.p_profile_id,target=profiles.find(x=>x.id===id);
     if(!target)return {error:{message:'Profil nicht gefunden'},data:null};
     if(fn==='admin_set_profile_role')target.role=params.p_role;
     if(fn==='admin_set_profile_active')target.is_active=params.p_active;
     if(fn==='admin_set_profile_listed')target.is_listed=params.p_listed;
     if(fn==='admin_set_profile_email')target.email=params.p_email;
     if(fn==='admin_set_profile_display_name'){window.__renamed=params;target.display_name=params.p_display_name}
     return {data:null,error:null};
   }
 };
}
`;
(async()=>{
 const server=http.createServer((req,res)=>{
   const rel=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\/+/,'');
   const file=path.join(root,rel||'index.html');
   if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return}
   res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'text/plain'});
   res.end(fs.readFileSync(file));
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port+'/admin.html';
 const browser=await chromium.launch({headless:true});
 try{
  for(const role of ['admin','coach','boxer']){
   const page=await browser.newPage({viewport:{width:390,height:844}});
   page.on('dialog',d=>d.accept());
   await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',route=>route.fulfill({
    status:200,contentType:'application/javascript',headers:{'access-control-allow-origin':'*'},body:mockModule
   }));
   await page.goto(base+'?role='+role,{waitUntil:'domcontentloaded'});
   await page.waitForTimeout(500);
   if(role==='admin'){
    await page.locator('#profilesBody tr').first().waitFor();
    assert.equal(await page.locator('#profilesBody tr').count(),4);
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=390),true,'mobile horizontal overflow at 390px');
    const labels=await page.locator('#profilesBody tr').allTextContents();
    assert.ok(labels.some(x=>x.includes('Neu angemeldeter Boxer')));
    assert.ok(labels.some(x=>x.includes('Noch kein Account')));
    const menu=page.locator('a[data-tl-admin]');
    await page.locator('#takeover-menu-open').click();
    await menu.waitFor({state:'visible'});
    const checkbox=page.locator('#profilesBody tr').filter({hasText:'Neu angemeldeter Boxer'}).locator('input[type=checkbox]').first();
    assert.equal(await checkbox.isVisible(),true);
    await page.keyboard.press('Escape');
    const row=page.locator('#profilesBody tr').filter({hasText:'Neu angemeldeter Boxer'});
    await row.locator('details.rename summary').click();
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=390),true,'rename field must not overflow at 390px');
    await row.locator('details.rename input').fill('altes PROFIL');
    await row.getByRole('button',{name:'Name speichern'}).click();
    await page.waitForFunction(()=>/archivierten Profil/.test(document.getElementById('adminStatus').textContent));
    await row.locator('details.rename input').fill('Coach mit Zugang');
    await row.getByRole('button',{name:'Name speichern'}).click();
    await page.waitForFunction(()=>/bereits vom Profil «Coach mit Zugang»/.test(document.getElementById('adminStatus').textContent));
    assert.equal(await page.evaluate(()=>window.__renamed===undefined),true,'Konfliktnamen dürfen nicht gesendet werden');
    await row.locator('details.rename input').fill('  Max   Muster ');
    await row.getByRole('button',{name:'Name speichern'}).click();
    await page.waitForFunction(()=>[...document.querySelectorAll('#profilesBody tr strong')].some(x=>x.textContent==='Max Muster'));
    const renamed=await page.evaluate(()=>window.__renamed);
    assert.deepEqual(renamed,{p_profile_id:'2',p_display_name:'Max Muster'},'rename RPC gets the trimmed name');
   }else{
    await page.waitForFunction(()=>document.getElementById('adminStatus').textContent.includes('Zugriff verweigert'));
    assert.equal(await page.locator('#adminContent').isVisible(),false);
    await page.locator('#takeover-menu-open').click();
    assert.equal(await page.locator('a[data-tl-admin]').isVisible(),false);
   }
   await page.close();
  }
  console.log('PASS: Admin UI at 390px, no overflow, admin-only navigation and access, admin renames a boxer');
 } finally {await browser.close();server.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
