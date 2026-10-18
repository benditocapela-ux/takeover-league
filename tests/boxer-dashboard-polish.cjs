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
assert.equal(doc.querySelectorAll('.boxer-quick-links a').length,1,'Studio must have exactly one hero CTA');
for(const [tabId,panelId] of [['studioTabOverview','studioPanelOverview'],['studioTabHistory','studioPanelHistory'],['studioTabDetails','studioPanelDetails']]){
 const tab=doc.getElementById(tabId),panel=doc.getElementById(panelId);
 assert.ok(tab&&panel,'Studio tab and panel missing: '+tabId);
 assert.equal(tab.getAttribute('role'),'tab');
 assert.equal(panel.getAttribute('role'),'tabpanel');
 assert.equal(tab.getAttribute('aria-controls'),panelId);
}
assert.ok(doc.getElementById('studioPanelOverview').contains(doc.getElementById('trainingFormCard')));
assert.ok(doc.getElementById('studioPanelHistory').contains(doc.getElementById('entriesCard')));
assert.ok(doc.getElementById('studioPanelDetails').contains(doc.getElementById('expRankSection')));
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

for(const token of ['--bx-bg:var(--bg)','--bx-gold:var(--gold)','#content.studio-content.hidden{display:none}', '.studio-pane[hidden]{display:none!important}', '.studio-tabs [role="tab"]']){
 assert.ok(css.includes(token),'Missing Studio token or concealed panel CSS: '+token);
}
assert.ok(html.includes('stroke-dasharray'),'Pure SVG EXP progress missing');
assert.ok(!/script\s+src=["']https?:/i.test(html),'Unexpected new third-party script');
doc.getElementById('avatarEditor').open=true;
assert.equal(doc.getElementById('avatarEditor').open,true,'Avatar edit controls must be expandable');
console.log('PASS: Boxer Studio design preserves original IDs, login/auth checks, training submit, avatar controls, EXP, stats, shared menu and responsive CSS.');
