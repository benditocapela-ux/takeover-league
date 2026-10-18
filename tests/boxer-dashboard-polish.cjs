const fs=require('node:fs');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const html=fs.readFileSync('boxer.html','utf8');
const css=fs.readFileSync('boxer-dashboard-polish.css','utf8');
const dom=new JSDOM(html,{url:'https://benditocapela-ux.github.io/takeover-league/boxer.html',runScripts:'outside-only'});
const doc=dom.window.document;
const requiredIds=[
 'logout','welcome','message','content','profileCard','avatarPreview','profileName',
 'avatarOptions','photo','saveAvatar','profileMessage','form','kind','points',
 'joggingField','joggingKm','techniqueField','techniqueMinutes','date','notes','submit',
 'totalKm','totalSprints','totalTechnique','typeBreakdown','entriesCard','refresh',
 'historyStats','statTotal','statApproved','statPending','statusFilter','entries',
 'moreEntries','expRankSection','expRankStatus','expRankDetails','expRankLetter',
 'expRankLevel','expRankTotal','expRankBar','performance30Section',
 'performance30Details','performance30Status','boxerFeedbackSection',
 'boxerFeedbackStatus','boxerFeedbackList','heroApproved','heroPending','heroTotal',
 'trainingFormCard','avatarEditor'
];
for(const id of requiredIds)assert.equal(doc.querySelectorAll('#'+id).length,1,'Missing or duplicate ID: '+id);
assert.equal(doc.querySelectorAll('form#form').length,1,'Training submission form should remain');
assert.equal(doc.querySelector('#kind').required,true);
assert.equal(doc.querySelector('#date').required,true);
assert.equal(doc.querySelector('#joggingKm').type,'number');
assert.equal(doc.querySelector('#techniqueMinutes').type,'number');
assert.equal(doc.querySelector('#photo').type,'file');
assert.equal(doc.querySelector('#avatarEditor').open,false,'Avatar editor must be collapsed by default');
assert.ok(doc.querySelector('#avatarEditor').contains(doc.querySelector('#avatarOptions')),'Avatar options must remain editable');
assert.ok(doc.querySelector('#avatarEditor').contains(doc.querySelector('#saveAvatar')),'Avatar save button must remain available');
assert.ok(doc.querySelector('#form').contains(doc.querySelector('#submit')),'Submit must stay inside training form');
assert.ok(doc.querySelector('.boxer-hero .boxer-quick-links a[href="#trainingFormCard"]'),'Quick submission link missing');
for(const href of ['./challenges.html','./duels.html']){
 assert.ok(doc.querySelector('.boxer-quick-links a[href="'+href+'"]'),'Quick V2 link missing: '+href);
}
assert.ok(doc.querySelector('link[href="./boxer-dashboard-polish.css"]'),'Polish styles missing');
assert.ok(doc.querySelector('link[href="./takeover-navigation.css"]'),'Common menu styles missing');
assert.ok(doc.querySelector('script[src="./takeover-navigation.js"]'),'Persistent menu missing');

const originalHandlers=[
 "db.from('training_submissions').insert",
 "db.from('training_submissions').select",
 "db.from('training_types').select",
 "db.auth.getUser()",
 "db.auth.signOut()",
 "await loadBoxerFeedback()",
 "await loadPerformance30()",
 "await loadExpRank()",
 "await initProfile()",
 "await loadPerformanceStats()"
];
for(const token of originalHandlers)assert.ok(html.includes(token),'Original live behavior accidentally changed: '+token);
assert.ok(html.includes("$('heroApproved').textContent=$('statApproved').textContent"),
 'Hero summary must reuse the same confirmed count as training history');
assert.ok(html.includes("$('heroPending').textContent=$('statPending').textContent"),
 'Hero summary must reuse the same pending count as training history');
assert.ok(html.includes("$('heroTotal').textContent=$('statTotal').textContent"),
 'Hero summary must reuse the same total count as training history');

for(const token of ['--bx-bg:#0b1220','--bx-gold:#dfbd77','#content.hidden{display:none}',
 '#content>#trainingFormCard','#content>#trainingStats',
 '#content>#expRankSection','#content>#performance30Section']){
 assert.ok(css.includes(token),'Missing polish or auth concealment CSS: '+token);
}
assert.ok(!/script\s+src=["']https?:/i.test(html),'Unexpected new third-party script');
doc.getElementById('avatarEditor').open=true;
assert.equal(doc.getElementById('avatarEditor').open,true,'Avatar edit controls must be expandable');
console.log('PASS: Boxer Hub design preserves original IDs, login/auth checks, training submit, avatar controls, EXP, stats, shared menu and responsive CSS.');
