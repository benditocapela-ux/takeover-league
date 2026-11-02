'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),{JSDOM}=require('jsdom');
const source=fs.readFileSync('coach.html','utf8');
const script=source.slice(source.indexOf('let competitionEpoch='),source.indexOf('// ---------------------------------------------------------------- Bereiche'));
assert.ok(script.includes('async function loadCompetitionStatus()'));
const page=counts=>({items:[],next_cursor:null,counts,state:'due',search:'',duel_id:null,metric:'points',limit:1,as_of:new Date().toISOString()});
async function mount({counts={all:127,open:2,due:3,ready:1,closed:120},error=null,role='coach',handler=null}={}){
 const dom=new JSDOM('<p id="coachDuelsStatus"></p>',{runScripts:'outside-only'});let event;const calls=[];
 dom.window.db={auth:{onAuthStateChange:fn=>{event=fn}},rpc:async(name,args)=>{calls.push([name,args]);return handler?handler():{data:page(counts),error}}};
 dom.window.eval(fs.readFileSync('takeover-duel-queue.js','utf8'));
 dom.window.eval("const $=id=>document.getElementById(id);let currentAdminId='coach',currentRole='"+role+"';"+script+';window.readStatus=loadCompetitionStatus;');
 await dom.window.readStatus();return {dom,calls,event,status:()=>dom.window.document.querySelector('p').textContent};
}
(async()=>{
 let f=await mount();assert.match(f.status(),/3 fällig/);assert.match(f.status(),/1 abschlussbereit/);assert.match(f.status(),/120 abgeschlossen/);assert.match(f.status(),/Alle Punkte-Duelle berücksichtigt/);assert.deepEqual(f.calls.map(x=>x[0]),['duel_v2_staff_queue']);f.dom.window.close();
 f=await mount({counts:{all:2000,open:0,due:0,ready:0,closed:2000}});assert.match(f.status(),/2.000 abgeschlossen/);assert.doesNotMatch(f.status(),/zuletzt 100/);f.dom.window.close();
 f=await mount({error:{code:'PGRST202'}});assert.match(f.status(),/nicht verfügbar/);assert.match(f.status(),/nicht als erledigt/);f.dom.window.close();
 f=await mount({counts:{all:5,open:0,due:2,ready:9,closed:3}});assert.match(f.status(),/nicht verfügbar/);f.dom.window.close();
 f=await mount({role:'boxer'});assert.equal(f.calls.length,0);f.dom.window.close();
 let release;f=await mount();f.dom.window.db.rpc=()=>new Promise(r=>{release=r});const pending=f.dom.window.readStatus();f.event('SIGNED_OUT');release({data:page({all:1,open:0,due:1,ready:1,closed:0}),error:null});await pending;assert.match(f.status(),/Bitte anmelden/);assert.doesNotMatch(f.status(),/fällig/);f.dom.window.close();
 console.log('Coach competition status: exact server counts beyond100, strict contract, failure, role and logout guards passed.');
})().catch(error=>{console.error(error);process.exitCode=1});
