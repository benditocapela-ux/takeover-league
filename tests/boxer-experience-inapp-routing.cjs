'use strict';
/* End-to-end navigation contract for Boxer Experience in-app subviews.
   Uses canonical pages in same-origin iframe; it must not create a second
   form, an alternate auth policy or client-side points awarding. */
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const read=p=>fs.readFileSync(p,'utf8');
const page=read('boxer-experience.html'),app=read('boxer-experience.js');
const flow=read('takeover-boxer-flow.js'),css=read('takeover-boxer-embedded-flow.css');
const canonical=read('boxer.html'),nav=read('takeover-navigation.js');
test('new five-tab shell contains a true embedded functional route, not a full page jump',()=>{
 assert.match(page,/id="ex-flow" class="ex-flow" hidden/);
 assert.match(page,/id="ex-flow-frame"/);
 assert.match(page,/id="ex-flow-back"/);
 assert.match(page,/id="ex-flow-loading"/);
 assert.match(page,/<script src="\.\/takeover-boxer-flow\.js" defer><\/script>/);
 assert.match(flow,/doc\.addEventListener\('click'/);
 assert.match(flow,/event\.preventDefault\(\)/);
 assert.match(flow,/shell\.hidden=!open/);
 assert.match(flow,/main\.hidden=open/);
 assert.match(flow,/tabs\.dataset\.flow=open/);
 assert.match(flow,/frame\.src=url\.href/);
 assert.match(flow,/frame\.addEventListener\('load',themedFrame\)/);
 assert.match(flow,/doc\.dispatchEvent\(new CustomEvent\('takeover:flow-closed'\)\)/);
 assert.match(app,/document\.addEventListener\('takeover:flow-closed'/);
 assert.doesNotThrow(()=>new vm.Script(flow));
 assert.doesNotThrow(()=>new vm.Script(app));
});
test('all 5-tab internal links except account open via the shared shell',()=>{
 const fromHtml=[...page.matchAll(/\bhref="(\.\/[^"]+\.html(?:\?[^"]*)?(?:#[^"]*)?)"/g)].map(x=>x[1]);
 const fromJs=[...app.matchAll(/['"](\.\/[^'"]+\.html(?:\?[^'"]*)?(?:#[^'"]*)?)['"]/g)].map(x=>x[1]);
 const hrefs=[...new Set([...fromHtml,...fromJs])];
 const allowed=flow.match(/const allowed=new Set\(\[([\s\S]*?)\]\)/)?.[1];
 assert.ok(allowed,'route allowlist exists');
 const list=new Set([...allowed.matchAll(/'([^']+\.html)'/g)].map(x=>x[1]));
 const exceptions=new Set(['login.html','boxer-experience.html','coach.html']);
 const missing=hrefs.map(h=>h.replace(/^\.\//,'').split(/[?#]/)[0]).filter(name=>!exceptions.has(name)&&!list.has(name));
 assert.deepEqual(missing,[],'all internal functional routes must remain in app');
 assert.ok(list.has('boxer.html')&&list.has('checkin.html')&&list.has('mein-boxer.html')&&list.has('shop.html'));
 assert.ok(list.has('index.html')&&list.has('wochenplan.html')&&list.has('quests.html'));
});
test('both club and individual forms still use canonical original submission code',()=>{
 assert.match(app,/\?individual=1#trainingFormCard/);
 assert.match(app,/\?club=1#trainingFormCard/);
 assert.match(app,/submit_scheduled_club_training_today/);
 assert.match(flow,/if\(path==='boxer\.html'&&!url\.hash\)url\.hash='#trainingFormCard'/);
 assert.match(css,/tl-ex-training #trainingFormCard/);
 assert.match(css,/tl-ex-training #trainingFormCard #form/);
 assert.match(css,/#content:not\(\.hidden\)/,'must not show the auth-gated form until login completes');
 assert.match(canonical,/id="form"/);
 assert.match(canonical,/id="trainingFormCard"/);
 assert.match(canonical,/data-tl-screen="boxer"/);
 assert.match(canonical,/TLTrainingV2/);
 assert.doesNotMatch(flow,/\.(?:insert|update|delete|upsert)\(/,'navigator must never persist training itself');
 assert.doesNotMatch(flow,/staff_review_training|training_reward_preview|point_transactions/);
});
test('same-origin allowlist and login separation are mandatory',()=>{
 assert.match(flow,/url\.origin!==location\.origin/);
 assert.match(flow,/url\.pathname\.startsWith\(root\.pathname\)/);
 assert.match(flow,/allowed\.has\(url\.pathname\.split\('\/'\)\.pop\(\)\)/);
 assert.match(flow,/event\.ctrlKey\|\|event\.metaKey\|\|event\.altKey\|\|event\.shiftKey/);
 assert.match(flow,/a\.hasAttribute\('download'\)/);
 assert.match(flow,/if\(page==='login\.html'\)/);
 assert.match(flow,/location\.assign\('\.\/login\.html\?next=boxer-experience\.html'\)/);
 assert.doesNotMatch(flow,/admin\.html'|'coach\.html'/);
 assert.match(app,/profile\.role!=='boxer'/);
});
test('theme hides redundant old chrome, not the training form or permissions',()=>{
 assert.match(css,/\.tl-screen-ribbon,.tl-subnav,.tl-global-bottom/);
 assert.match(css,/\.studio-pane-overview>.card:not\(#trainingFormCard\)/);
 assert.match(css,/tl-ex-training #submit/);
 assert.match(css,/\.tl-v2-step/);
 assert.doesNotMatch(css,/\#trainingFormCard[^{]*\{[^}]*display:none/);
 assert.match(page,/class="ex-menu"/);
 assert.match(nav,/boxer:\{href:'\.\/boxer-experience\.html'/);
});
