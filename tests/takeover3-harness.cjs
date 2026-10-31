'use strict';
// Takeover 3.0 · gemeinsame Test-Umgebung: statischer Server + Supabase-Attrappe (nur im Browser, keine echten Daten).
// Die Attrappe verhält sich wie supabase-js: Sitzung unter sb-<ref>-auth-token im localStorage, setSession prüft
// das Refresh-Token gegen einen simulierten Server (widerrufene Tokens schlagen fehl), signOut widerruft serverseitig.
// Tabellen und Inserts liegen in localStorage (__tl_mock_db) und überleben Seitenwechsel.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'..');
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.woff':'font/woff','.png':'image/png','.webp':'image/webp','.json':'application/json','.webmanifest':'application/manifest+json'};
function serve(){
 const server=http.createServer((req,res)=>{
  const rel=decodeURIComponent(new URL(req.url,'http://x').pathname).replace(/^\/+/,'')||'index.html';
  const file=path.join(root,rel);
  if(!file.startsWith(root)||!fs.existsSync(file)||fs.statSync(file).isDirectory()){res.writeHead(404);return res.end()}
  res.writeHead(200,{'content-type':mime[path.extname(file)]||'application/octet-stream','cache-control':'no-store'});fs.createReadStream(file).pipe(res);
 });
 return new Promise(r=>server.listen(0,'127.0.0.1',()=>r({server,base:'http://127.0.0.1:'+server.address().port})));
}
const KEY='sb-iqarjivcrddcixrvqbfb-auth-token';
// Wird als ES-Modul anstelle von supabase-js ausgeliefert.
const MOCK=String.raw`
const KEY='${KEY}';
const S=()=>{try{return JSON.parse(localStorage.getItem('__tl_mock_server')||'{}')}catch{return {}}};
const saveS=s=>localStorage.setItem('__tl_mock_server',JSON.stringify(s));
const DB=()=>{try{return JSON.parse(localStorage.getItem('__tl_mock_db')||'{}')}catch{return {}}};
const saveDB=d=>localStorage.setItem('__tl_mock_db',JSON.stringify(d));
const cfg=()=>window.__tlMockConfig||{};
const log=(k,v)=>{const l=JSON.parse(localStorage.getItem('__tl_mock_log')||'[]');l.push([k,v]);localStorage.setItem('__tl_mock_log',JSON.stringify(l))};
const read=()=>{try{return JSON.parse(localStorage.getItem(KEY)||'null')}catch{return null}};
const b64=o=>btoa(JSON.stringify(o)).replace(/=+$/,'');
function issue(user,expired){const s=S();s.seq=(s.seq||0)+1;const rt='rt-'+user.id+'-'+s.seq;s.valid=s.valid||{};s.valid[rt]=user.id;saveS(s);
 const exp=Math.floor(Date.now()/1000)+(expired?-60:3600);
 return {access_token:'h.'+b64({sub:user.id,exp})+'.s',refresh_token:rt,expires_at:exp,expires_in:3600,token_type:'bearer',user}}
function userById(id){return (cfg().users||[]).find(u=>u.id===id)||null}
function match(row,f){const [op,k,v]=f;const x=row[k];
 if(op==='eq')return String(x)===String(v);if(op==='neq')return String(x)!==String(v);if(op==='in')return v.map(String).includes(String(x));
 if(op==='gte')return x>=v;if(op==='lte')return x<=v;if(op==='is')return v===null?x==null:x===v;return true}
function table(name){const d=DB();return Array.isArray(d[name])?d[name]:(cfg().tables&&cfg().tables[name])||[]}
function query(name){
 const st={filters:[],one:false,order:null,limit:null,op:'select',payload:null,opts:null};
 const b={select(){return b},eq(k,v){st.filters.push(['eq',k,v]);return b},neq(k,v){st.filters.push(['neq',k,v]);return b},in(k,v){st.filters.push(['in',k,v]);return b},
  gte(k,v){st.filters.push(['gte',k,v]);return b},lte(k,v){st.filters.push(['lte',k,v]);return b},is(k,v){st.filters.push(['is',k,v]);return b},
  order(k,o){st.order=[k,o&&o.ascending===false?-1:1];return b},limit(n){st.limit=n;return b},range(a,z){st.limit=z-a+1;return b},not(){return b},or(){return b},filter(){return b},ilike(){return b},
  maybeSingle(){st.one='maybe';return b},single(){st.one='single';return b},
  insert(p){st.op='insert';st.payload=p;return b},upsert(p,o){st.op='upsert';st.payload=p;st.opts=o;return b},update(p){st.op='update';st.payload=p;return b},delete(){st.op='delete';return b},
  then(res,rej){return run().then(res,rej)}};
 async function run(){
  const hook=cfg().fail&&cfg().fail[name+':'+st.op];
  if(hook)return {data:null,error:hook};
  const d=DB();let rows=table(name).slice();
  if(st.op==='insert'){const list=Array.isArray(st.payload)?st.payload:[st.payload];
   for(const p of list){if(name==='training_submissions'&&p.client_request_id&&rows.some(r=>r.client_request_id===p.client_request_id))return {data:null,error:{code:'23505',message:'duplicate key value violates unique constraint'}};
    const row={id:'ts-'+Math.random().toString(36).slice(2),created_at:new Date().toISOString(),...p};rows.unshift(row);log('insert:'+name,row)}
   d[name]=rows;saveDB(d);return {data:null,error:null}}
  if(st.op==='upsert'){const p=st.payload;const key=(st.opts&&st.opts.onConflict)||'id';rows=rows.filter(r=>String(r[key])!==String(p[key]));rows.unshift(p);d[name]=rows;saveDB(d);log('upsert:'+name,p);return {data:null,error:null}}
  if(st.op==='delete'){d[name]=rows.filter(r=>!st.filters.every(f=>match(r,f)));saveDB(d);log('delete:'+name,st.filters);return {data:null,error:null}}
  if(st.op==='update'){d[name]=rows.map(r=>st.filters.every(f=>match(r,f))?{...r,...st.payload}:r);saveDB(d);return {data:null,error:null}}
  if(name==='profiles'){const s=read();if(!s)rows=[]}
  rows=rows.filter(r=>st.filters.every(f=>match(r,f)));
  if(st.order){const [k,dir]=st.order;rows.sort((a,z)=>a[k]<z[k]?-dir:a[k]>z[k]?dir:0)}
  if(st.limit!=null)rows=rows.slice(0,st.limit);
  const data=st.one?(rows[0]||null):rows;
  if(st.one==='single'&&!rows[0])return {data:null,error:{code:'PGRST116',message:'no rows'}};
  return {data,error:null,count:Array.isArray(data)?data.length:null};
 }
 return b;
}
export function createClient(){
 const listeners=[];const emit=(e,s)=>listeners.forEach(cb=>{try{cb(e,s)}catch{}});
 const auth={
  async getSession(){return {data:{session:read()},error:null}},
  async getUser(){const s=read();if(!s)return {data:{user:null},error:{message:'Auth session missing!'}};
   const v=S().valid||{};if(!v[s.refresh_token])return {data:{user:null},error:{message:'Invalid Refresh Token'}};return {data:{user:s.user},error:null}},
  async signInWithPassword({email,password}){const u=(cfg().users||[]).find(x=>x.email===email);
   if(!u||password!==(u.password||'pw'))return {data:{user:null,session:null},error:{message:'Invalid login credentials'}};
   const s=issue(u);localStorage.setItem(KEY,JSON.stringify(s));emit('SIGNED_IN',s);return {data:{user:u,session:s},error:null}},
  async setSession({access_token,refresh_token}){if(!access_token||!refresh_token)return {data:{session:null},error:{message:'Auth session missing!'}};
   const srv=S();const uid=srv.valid&&srv.valid[refresh_token];if(!uid){log('setSession:fail',refresh_token);return {data:{session:null,user:null},error:{message:'Invalid Refresh Token: Refresh Token Not Found'}}}
   delete srv.valid[refresh_token];saveS(srv);const s=issue(userById(uid));localStorage.setItem(KEY,JSON.stringify(s));log('setSession:ok',uid);emit('SIGNED_IN',s);return {data:{session:s,user:s.user},error:null}},
  async signOut(){const s=read();if(s){const srv=S();for(const [rt,uid] of Object.entries(srv.valid||{}))if(uid===s.user.id)delete srv.valid[rt];saveS(srv)}
   localStorage.removeItem(KEY);log('signOut',s&&s.user.id);emit('SIGNED_OUT',null);return {error:null}},
  onAuthStateChange(cb){listeners.push(cb);return {data:{subscription:{unsubscribe(){}}}}},
  async resetPasswordForEmail(){return {error:null}},async updateUser(){return {data:{},error:null}},async signUp(){return {data:{},error:null}}
 };
 return {auth,from:query,
  async rpc(name,args){log('rpc:'+name,args||null);const h=cfg().rpc&&cfg().rpc[name];
   if(typeof h==='function')return h(args||{});if(h!==undefined)return {data:h,error:null};return {data:null,error:{code:'PGRST202',message:'Function not found: '+name}}},
  storage:{from:()=>({upload:async()=>({error:null}),getPublicUrl:()=>({data:{publicUrl:''}})})},
  channel(){const c={on(){return c},subscribe(){return c}};return c},removeChannel(){},removeAllChannels(){}};
}`;
async function context(browser,{viewport={width:390,height:844},config='{}',isMobile=false}={}){
 const ctx=await browser.newContext({viewport,isMobile,hasTouch:isMobile});
 await ctx.addInitScript('window.__tlMockConfig='+config+';');
 await ctx.route(/cdn\.jsdelivr\.net/,r=>r.fulfill({status:200,contentType:'text/javascript',headers:{'access-control-allow-origin':'*'},body:MOCK}));
 await ctx.route(/^https?:\/\/(?!127\.0\.0\.1)(?!cdn\.jsdelivr)/,r=>r.abort());
 return ctx;
}
module.exports={serve,context,KEY,root};
