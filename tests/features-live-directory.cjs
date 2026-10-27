'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('jsdom');
const html=fs.readFileSync('features.html','utf8');
const code=[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)]
  .find(x=>x[1].includes('refreshFeatureDirectory'))?.[1];
assert.ok(code,'Feature status logic missing');
function flush(){return new Promise(resolve=>setTimeout(resolve,30))}
async function checkFixture(enabled,shouldFail=false){
 const dom=new JSDOM(html,{url:'https://example.test/takeover-league/features.html',runScripts:'outside-only'});
 try{
  const hits=[];
  dom.window.fetch=async (url,options)=>{
   hits.push({url,options});
   if(shouldFail)throw Error('Mocked offline');
   return {ok:true,json:async()=>enabled.map(feature_key=>({feature_key,is_enabled:true}))};
  };
  dom.window.eval(code);
  await flush();
  const cards=[...dom.window.document.querySelectorAll('#features .card')];
  assert.equal(cards.length,11,'All original feature cards must remain');
  assert.equal(hits.length,1,'Only one read-only flag API request');
  assert.match(hits[0].url,/rest\/v1\/league_feature_flags\?select=feature_key,is_enabled/);
  assert.equal(hits[0].options.credentials,'omit');
  const badges=cards.map(c=>c.querySelector('.badge').textContent);
  if(shouldFail){
   // League 2.1 pages need no flag and stay reachable while the flag API is offline.
   for(const index of [4,5,9,10])assert.equal(badges[index],'LIVE','2.1 page must stay live offline');
   assert.ok(badges.filter((_,i)=>![4,5,9,10].includes(i)).every(x=>x==='STATUS NICHT VERFÜGBAR'));
   assert.match(dom.window.document.querySelector('#featureStatus').textContent,/nicht abrufbar/);
   return;
  }
  assert.equal(badges.filter(x=>x==='LIVE').length,enabled.length+4);
  for(const [index,path] of [
   [0,'boxer.html#achievementsV2'],[1,'duels.html'],[2,'boxer.html#boxerFeedbackSection'],
   [3,'challenges.html'],[4,'league-history.html'],[5,'league-challenges.html'],[6,'boxer.html#boxerNotificationSection'],
   [8,'boxer.html#performance30Section'],[9,'index.html#ranking'],[10,'league-history.html']
  ])assert.ok(cards[index].href.endsWith(path),'Live feature route mismatch '+path);
  for(const index of [7])
   assert.match(cards[index].href,/coming-soon.html\?feature=/,'Disabled feature should remain gated');
 }finally{dom.window.close()}
}
(async()=>{
 await checkFixture(['achievements','duels','coach_feedback','coach_challenges','notifications','performance_dashboard']);
 await checkFixture([],true);
 console.log('PASS: Live feature directory routes, flag mapping, safe offline states and no authenticated access.');
})().catch(e=>{console.error(e);process.exitCode=1});
