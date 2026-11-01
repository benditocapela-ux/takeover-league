/* Takeover League 3.0 · statische Verträge. Run: node --test tests/takeover3-contracts.cjs
 * App-Shell auf allen Seiten, sicherer Konto-Umschalter, integriertes Trainingsformular, zentrale Legacy-Weiterleitung. */
'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.join(__dirname,'..');const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const shell=read('takeover-app-shell.js'),account=read('takeover-account.js'),form=read('takeover-training-form.js'),studio=read('boxer-experience-studio.js');
const exp=read('boxer-experience.html'),expJs=read('boxer-experience.js'),login=read('login.html'),nav=read('takeover-navigation.js');
const PREVIEWS=new Set(['challenges-v2-preview.html','duels-v2-preview.html','league2-preview.html']);
const pages=fs.readdirSync(root).filter(f=>f.endsWith('.html')&&!PREVIEWS.has(f));

test('new modules are valid scripts',()=>{
 for(const [n,src] of [['shell',shell],['account',account],['form',form],['studio',studio],['experience',expJs],['nav',nav]])assert.doesNotThrow(()=>new vm.Script(src),n);
});
test('every user-facing page loads the shared app shell and account component in order',()=>{
 for(const p of pages){const s=read(p);
  assert.ok(s.includes('href="./takeover-app-shell.css"'),p+' shell css');
  const a=s.indexOf('src="./takeover-account.js"'),b=s.indexOf('src="./takeover-app-shell.js"');
  assert.ok(a>0&&b>a,p+': takeover-account.js before takeover-app-shell.js');
 }
});
test('no iframe and no embedded legacy flow in the Boxer Experience',()=>{
 assert.doesNotMatch(exp,/<iframe|ex-flow|takeover-boxer-flow/);
 assert.ok(!fs.existsSync(path.join(root,'takeover-boxer-flow.js')));
 assert.match(exp,/takeover-training-form\.js/);assert.match(exp,/boxer-experience-studio\.js/);
 assert.doesNotMatch(expJs,/boxer\.html/);
});
test('account switching uses the official Supabase API, never patches Storage or writes the session key',()=>{
 assert.doesNotMatch(account+shell+nav+login,/Storage\.prototype\.\w+\s*=/);
 assert.doesNotMatch(account+shell,/setItem\([^)]*auth-token/);
 assert.match(account,/db\.auth\.setSession\(\{access_token:target\.at\|\|'',refresh_token:target\.rt\}\)/);
 assert.match(account,/takeover_accounts_v2/);assert.match(account,/removeItem\(LEGACY\)/);
 assert.doesNotMatch(account,/password/i.source&&/\.password\b/);
 assert.match(account,/MAX=5/);
 // Server re-checks role and active state after every switch
 assert.match(account,/profileOf\(db\)/);assert.match(account,/p\.is_active\?homeFor\(p\.role\)/);
 // expired / revoked refresh tokens lead to re-authentication
 assert.match(account,/needsLogin:true/);assert.match(shell+account,/login\.html\?add=1&account=/);
 // stored entries never hold full session or user objects
 assert.doesNotMatch(account,/session:raw|session:\s*JSON\.stringify/);
});
test('role homes: boxer → Boxer Experience, coach → Trainer-Dashboard, admin → Clubverwaltung',()=>{
 for(const src of [account,login])assert.match(src,/boxer:'\.\/boxer-experience\.html',coach:'\.\/coach\.html',admin:'\.\/admin\.html'/);
 assert.doesNotMatch(login,/location\.replace\('\.\/boxer\.html'\)/);
 assert.doesNotMatch(read('index.html'),/'boxer'\?'\.\/boxer\.html'/);
});
test('central legacy routing maps old boxer links into the new views',()=>{
 const ctx={window:{},location:{href:'https://x.test/takeover-league/index.html',pathname:'/takeover-league/index.html',hash:''},document:{readyState:'loading',addEventListener(){},documentElement:{classList:{add(){}}}},
  URL,addEventListener(){},localStorage:{getItem:()=>null},console};
 ctx.window=ctx;vm.createContext(ctx);vm.runInContext(shell,ctx);
 const t=(u,r='boxer')=>ctx.TLShell.legacyTarget('https://x.test/takeover-league/'+u,r);
 assert.equal(t('boxer.html?individual=1#trainingFormCard'),'./boxer-experience.html#training/eigenes');
 assert.equal(t('boxer.html?club=1#trainingFormCard'),'./boxer-experience.html#training/verein');
 assert.equal(t('boxer.html#entriesCard'),'./boxer-experience.html#training/historie');
 assert.equal(t('boxer.html#boxerNotificationSection'),'./boxer-experience.html#heute/mitteilungen');
 assert.equal(t('boxer.html#profileCard'),'./boxer-experience.html#boxer/profil');
 assert.equal(t('boxer.html'),'./boxer-experience.html#training');
 assert.equal(t('boxer.html','coach'),null,'coaches keep their own training form');
 assert.equal(t('shop.html'),null);
});
test('training form writes only pending requests; server owns tier, points, EXP and coins',()=>{
 const writes=[...form.matchAll(/from\('([a-z_0-9]+)'\)\.(insert|upsert|update|delete)\(/g)].map(m=>m[1]+':'+m[2]);
 assert.deepEqual([...new Set(writes)].sort(),['training_drafts_v2:delete','training_drafts_v2:upsert','training_submissions:insert']);
 assert.match(form,/status:'pending'/);
 const build=form.slice(form.indexOf('function buildPayload'),form.indexOf('function validate'));
 assert.doesNotMatch(build,/club_tier|points|\bexp\b|coins|approved/);
 assert.doesNotMatch(form,/status:'approved'|club_tier\s*:/);
 assert.match(form,/client_request_id/);assert.match(form,/r\.error\.code==='23505'/);
 assert.match(form,/if\(st\.busy\)return/);
 for(const key of ['takeover_draft_','takeover_submission_request_','takeover_last_training_','takeover_last_type_','takeover_v2_choice_'])assert.ok(form.includes(key),key);
 assert.match(form,/training_location:'club',requested_slot_id/);
});
test('training form validation mirrors the established rules',()=>{
 const ctx={window:{},document:{},crypto:{},console};ctx.window=ctx;vm.createContext(ctx);vm.runInContext(form,ctx);
 const F=ctx.TLTrainingForm,today='2026-11-04';
 const jog={id:2,name:'Joggen'},tech={id:3,name:'Techniktraining'};
 const ok={date:'2026-11-02',minutes:'45',km:'5',notes:'Lauf'};
 assert.equal(F.validate({type:jog,values:ok,v2:false,today}),null);
 assert.match(F.validate({type:null,values:ok,v2:false,today}).message,/Trainingsart/);
 assert.match(F.validate({type:jog,values:{...ok,date:'2026-11-05'},v2:false,today}).message,/Zukunft/);
 assert.match(F.validate({type:jog,values:{...ok,minutes:'0'},v2:false,today}).message,/Trainingsdauer/);
 assert.match(F.validate({type:jog,values:{...ok,km:''},v2:false,today}).message,/Joggingdistanz/);
 assert.match(F.validate({type:jog,values:{...ok,notes:'ab'},v2:false,today}).message,/Bemerkung/);
 assert.match(F.validate({type:jog,values:ok,v2:true,today}).message,/wo du trainiert/);
 assert.match(F.validate({type:jog,values:ok,v2:true,loc:'club',today}).message,/Vereinseinheit/);
 assert.match(F.validate({type:jog,values:ok,v2:true,loc:'club',slot:{dow:3,label:'Reguläres Boxtraining',day_name:'Mittwoch'},today}).message,/Mittwoch/);
 const p=F.buildPayload({profile:{id:'p1'},type:tech,values:{date:'2026-11-02',minutes:'60',notes:' Pratzen '},v2:true,loc:'individual',requestId:'r1'});
 assert.equal(p.technique_minutes,60);assert.equal(p.jogging_km,null);assert.equal(p.notes,'Pratzen');assert.equal(p.status,'pending');
 assert.equal(p.training_location,'individual');assert.equal(p.client_request_id,'r1');
 const q=F.buildPayload({profile:{id:'p1'},type:jog,values:{date:'2026-11-02',minutes:'30',km:'4.2',notes:'x y z'},v2:false});
 assert.equal(q.jogging_km,4.2);assert.equal('training_location' in q,false);
});
test('studio writes are limited to avatar and notification read state',()=>{
 assert.doesNotMatch(studio,/\.(?:insert|upsert|delete)\(/);
 const rpcs=[...studio.matchAll(/rpc\('([a-z_0-9]+)'/g)].map(m=>m[1]);
 for(const r of rpcs)assert.ok(['league_training_audit_recent','mark_my_notification_read','update_my_boxer_avatar','get_boxer_exp_level_rank','get_boxer_performance_30d','get_my_feedback'].includes(r),r);
 assert.match(studio,/eq\('boxer_id',S\.profile\.id\)/);assert.match(studio,/eq\('recipient_id',S\.profile\.id\)/);
});
test('role-based navigation for boxer, coach, admin and guests; legacy chrome hidden when the shell runs',()=>{
 for(const r of ['boxer:[','coach:[','admin:[','guest:['])assert.ok(shell.includes(r),r);
 const css=read('takeover-app-shell.css');
 assert.match(css,/html\.tla-on \.tl-global-bottom/);assert.match(css,/html\.tla-on header\.tl-subnav/);
 assert.match(css,/min-height:44px/);assert.match(css,/env\(safe-area-inset-top/);assert.match(css,/env\(safe-area-inset-bottom/);
 assert.match(css,/html\.tla-typing \.tla-nav/,'nav hides while the iPhone keyboard is open');
});
test('early boxer.html guard redirects exactly like TLShell.legacyTarget',()=>{
 const html=read('boxer.html');const src=html.slice(html.indexOf('<script>')+8,html.indexOf('</script>'));
 const shellCtx={window:{},location:{href:'https://x.test/t/index.html',pathname:'/t/index.html',hash:''},document:{readyState:'loading',addEventListener(){},documentElement:{classList:{add(){}}}},URL,addEventListener(){},localStorage:{getItem:()=>null},console};
 shellCtx.window=shellCtx;vm.createContext(shellCtx);vm.runInContext(shell,shellCtx);
 for(const u of ['boxer.html','boxer.html?individual=1#trainingFormCard','boxer.html?club=1#trainingFormCard','boxer.html#entriesCard','boxer.html#profileCard','boxer.html#boxerNotificationSection','boxer.html#achievementsV2']){
  const url=new URL('https://x.test/t/'+u);let target=null;
  const store={'sb-iqarjivcrddcixrvqbfb-auth-token':JSON.stringify({user:{id:'u1'}}),takeover_accounts_v2:JSON.stringify([{id:'u1',role:'boxer'}])};
  const ctx={localStorage:{getItem:k=>store[k]||null},URLSearchParams,JSON,location:{search:url.search,hash:url.hash,replace:t=>{target=t}},document:{documentElement:{style:{}}}};
  vm.createContext(ctx);vm.runInContext(src,ctx);
  assert.equal(target,shellCtx.TLShell.legacyTarget(url.href,'boxer'),u);
 }
 // Trainer werden nicht umgeleitet
 let moved=false;const ctx={localStorage:{getItem:k=>k.startsWith('sb-')?JSON.stringify({user:{id:'u1'}}):JSON.stringify([{id:'u1',role:'coach'}])},URLSearchParams,JSON,location:{search:'',hash:'',replace:()=>{moved=true}},document:{documentElement:{style:{}}}};
 vm.createContext(ctx);vm.runInContext(src,ctx);assert.equal(moved,false);
});
