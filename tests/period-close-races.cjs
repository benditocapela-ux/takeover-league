'use strict';
// Period close pre-RPC races; synthetic DOM/auth only, no database writes.
const fs=require('node:fs'),assert=require('node:assert/strict'),{JSDOM}=require('jsdom');
const script=fs.readFileSync('takeover-period-close.js','utf8'),tick=()=>new Promise(r=>setTimeout(r,0));
async function mount(){
 const dom=new JSDOM('<section id="host"></section>',{runScripts:'outside-only'}),w=dom.window;
 w.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};w.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
 let actor='staff-a',hold=false;const pending=[],calls=[];
 const db={auth:{getUser:()=>hold?new Promise(resolve=>pending.push(resolve)):Promise.resolve({data:{user:{id:actor}},error:null})},from:()=>({select(){return this},eq(){return this},maybeSingle:async()=>({data:{role:'coach',is_active:true,archived_at:null},error:null})}),rpc:async(name,args)=>{calls.push({name,args});if(name==='league_period_close_preview')return {data:{version:1,kind:args.p_kind,key:args.p_key,title:args.p_key,revision:'a'.repeat(32),rows:[],blockers:[],ranked_count:0,can_close:true,trainings:{approved:0,pending:0,rejected:0},reward:{additional_payout:false,status:'not_configured',planned_bookings:[]},starts_on:'2026-10-01',ends_on:'2026-10-31',status:'awaiting_close'},error:null};return {data:{status:'closed',kind:args.p_kind,key:args.p_key,additional_payout:false,bookings:[],unchanged:false},error:null}}};
 w.eval(script);const ui=w.TLPeriodClose.create({host:w.document.querySelector('#host'),db}),dialog=w.document.querySelector('dialog');
 const open=w.document.querySelector('#host button'),confirm=[...dialog.querySelectorAll('button')].find(b=>/verbindlich/.test(b.textContent)),close=[...dialog.querySelectorAll('button')].find(b=>b.textContent==='Schliessen');
 await ui.setPeriod('month','2026-10');
 return {dom,w,ui,dialog,open,confirm,close,calls,pending,hold(value){hold=value},actor(value){actor=value},resolve(subject){const resolve=pending.shift();assert.ok(resolve,'pending auth lookup exists');resolve({data:{user:{id:subject}},error:null})},async preview(){open.click();await tick();await tick();assert.equal(confirm.hidden,false)}};
}
(async()=>{
 for(const mode of ['close','escape']){
  const f=await mount();await f.preview();f.hold(true);f.confirm.click();assert.equal(f.pending.length,1);if(mode==='close')f.close.click();else f.dialog.dispatchEvent(new f.w.Event('cancel',{cancelable:true}));f.resolve('staff-a');await tick();await tick();assert.equal(f.calls.filter(c=>c.name==='league_period_close_confirm').length,0,mode+' while auth pending prevents later booking request');assert.equal(f.dialog.open,false);f.dom.window.close();
 }
 for(const newActor of ['staff-a','staff-b']){
  const f=await mount();await f.preview();f.hold(true);f.confirm.click();f.ui.clear();f.actor(newActor);f.hold(false);await f.ui.setPeriod('month','2026-09');f.resolve(newActor);await tick();await tick();assert.equal(f.calls.filter(c=>c.name==='league_period_close_confirm').length,0,'old consent cannot move to '+newActor+' or new period');f.dom.window.close();
 }
 for(const mode of ['escape','account']){
  const f=await mount();f.hold(true);f.open.click();assert.equal(f.pending.length,1);if(mode==='escape')f.dialog.dispatchEvent(new f.w.Event('cancel',{cancelable:true}));else{f.ui.clear();f.actor('staff-b');f.hold(false);await f.ui.setPeriod('month','2026-09')}f.resolve(mode==='account'?'staff-b':'staff-a');await tick();await tick();assert.equal(f.calls.length,0,'obsolete preview auth must not issue a read RPC');f.dom.window.close();
 }
 const f=await mount();await f.preview();f.confirm.click();await tick();await tick();const sent=f.calls.filter(c=>c.name==='league_period_close_confirm');assert.equal(sent.length,1);assert.deepEqual(JSON.parse(JSON.stringify(sent[0].args)),{p_kind:'month',p_key:'2026-10',p_confirm:true,p_revision:'a'.repeat(32)});assert.match(f.dialog.textContent,/Ergebnis offiziell gespeichert/);f.dom.window.close();
 console.log('Period close races: close/Escape, same/different staff replacement, obsolete preview, exact normal consent passed.');
})().catch(error=>{console.error(error);process.exitCode=1});
