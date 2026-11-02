'use strict';
// Real browser/real form: a fast synthetic insert can move a success action under
// the second click. Scroll the existing container; do not change layout or timers.
const pw=require('playwright'),assert=require('node:assert/strict'),H=require('./takeover3-harness.cjs');
const config=JSON.stringify({users:[{id:'u-ben',email:'ben@test.invalid'}],tables:{
 profiles:[{id:'p-ben',auth_user_id:'u-ben',display_name:'Ben',role:'boxer',is_active:true}],
 training_types:[{id:2,name:'Joggen',points:20,is_active:true,category:'Ausdauer'}],
 training_submissions:[],training_drafts_v2:[],league_feature_flags:[]},
 rpc:{get_training_v2_config:{enabled:true,pflicht:[],extras:[],types:[{id:2,name:'Joggen',club_only:false,reward:{points:20,exp:20}}]},get_public_leaderboard:[]}});
async function fill(page){
 await page.selectOption('#tf-kind','2');await page.fill('#tf-minutes','45');
 await page.fill('#tf-km','6.5');await page.fill('#tf-notes','Synthetic double-click regression');
}
async function scenario(browser,base,name,action){
 const ctx=await H.context(browser,{config}),page=await ctx.newPage();
 try{
  await page.addInitScript(()=>{window.__successClicks=[];document.addEventListener('click',e=>{
   if(e.target.closest('.tf-done button'))window.__successClicks.push({detail:e.detail,text:e.target.textContent});
  },true)});
  await page.goto(base+'/login.html');await page.fill('#email','ben@test.invalid');await page.fill('#password','pw');await page.click('#loginBtn');
  await page.waitForURL(/boxer-experience\.html/);await page.goto(base+'/boxer-experience.html#training');
  await page.click('.ex-choice:has-text("Nein, eigenes Training")');await fill(page);
  await page.locator('.tf-form > .tf-submit').click();await page.locator('.tf-done:not([hidden])').waitFor();
  const selector=action==='back'?'.tf-done .tf-submit':'.tf-done .tf-chip';
  await page.locator(selector).scrollIntoViewIfNeeded();
  const target=await page.locator(selector).boundingBox();assert.ok(target);
  // This intentional single click also proves that immediate normal actions work.
  await page.locator('.tf-done .tf-chip').click();await fill(page);
  const point={x:target.x+target.width/2,y:target.y+target.height/2};
  await page.evaluate(point=>{
   const submit=document.querySelector('.tf-form > .tf-submit'),r=submit.getBoundingClientRect();
   document.querySelector('.ex-scroll').scrollBy(0,r.top+r.height/2-point.y);
  },point);
  await page.locator('.tf-form > .tf-submit').scrollIntoViewIfNeeded();
  const submit=await page.locator('.tf-form > .tf-submit').boundingBox();assert.ok(submit);
  await page.locator('.tf-form > .tf-submit').dblclick({delay:30,position:{x:point.x-submit.x,y:submit.height/2}});
  const clicks=await page.evaluate(()=>window.__successClicks);
  assert.ok(clicks.some(e=>e.detail===2&&e.text.includes(action==='back'?'Trainingsübersicht':'Weiteres Training')),
   name+' '+action+': the second real click must actually hit the newly rendered action '+JSON.stringify({point,submit,after:await page.locator(selector).boundingBox(),clicks}));
  assert.equal(await page.locator('.tf-done').isVisible(),true,name+' '+action+': success stays visible after double click');
  assert.match(page.url(),/#training\/eigenes$/);
  const inserts=await page.evaluate(()=>JSON.parse(localStorage.getItem('__tl_mock_log')||'[]').filter(([k])=>k==='insert:training_submissions').length);
  assert.equal(inserts,2,'one calibration insert plus one double-click insert');
  await page.locator(selector).click();
  if(action==='back'){await page.waitForURL(/#training$/);await page.click('.ex-choice:has-text("Nein, eigenes Training")')}
  else await page.locator('.tf-form:not([hidden])').waitFor();
  await fill(page);await page.locator('.tf-form > .tf-submit').click();await page.locator('.tf-done:not([hidden])').waitFor();
  await page.locator(selector).focus();await page.keyboard.press('Enter');
  if(action==='back')await page.waitForURL(/#training$/);else await page.locator('.tf-form:not([hidden])').waitFor();
  console.log('PASS '+name+' '+action+': actual second-click collision ignored; single click and Enter remain usable');
 }finally{await ctx.close()}
}
(async()=>{
 const {server,base}=await H.serve();
 try{for(const name of ['chromium','webkit']){const browser=await pw[name].launch();
  try{for(const action of ['back','again'])await scenario(browser,base,name,action)}finally{await browser.close()}
 }}finally{server.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
