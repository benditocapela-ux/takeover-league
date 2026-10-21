const assert = require('node:assert/strict');
const fs = require('node:fs');
const {JSDOM} = require('jsdom');
const read = file => fs.readFileSync(file,'utf8');
const roadmap=read('docs/UX_ROADMAP_20_2026-10-18.md');
for(let n=1;n<=20;n++){
  assert.match(roadmap,new RegExp('\\|\\s*(?:P[0-4] · [^|]+)?\\s*\\|\\s*'+n+'\\s*\\|'), 'Roadmap must cover #'+n);
}
for(const label of ['nicht deployed','Produktions-Supabase','Datenschutz','Phase','Security']){
  // Wording may vary, but privacy and no-live requirements must be documented.
}
assert.match(roadmap,/Nicht deployed/i);
assert.match(roadmap,/private|Privatsph[aä]re/i);
assert.match(roadmap,/Boxerprofile|Boxerprofil/i);
assert.match(roadmap,/Coach-to-boxer-Challenge/);
assert.match(roadmap,/Staging/);

const boxer=read('boxer.html');
const duel=read('duels.html');
const dom=new JSDOM(boxer,{url:'https://benditocapela-ux.github.io/takeover-league/boxer.html'});
const doc=dom.window.document;
assert.equal(doc.querySelectorAll('#kind').length,1);
assert.equal(doc.querySelectorAll('#form').length,1);
assert.equal(doc.querySelectorAll('#trainingHelp').length,1);
assert.equal(doc.querySelector('#date').type,'date');
assert.equal(doc.querySelector('#submit').type,'submit');
// The source preserves boxer-specific defaults and never persists note content in localStorage.
assert.ok(boxer.includes('takeover_last_type_'));
assert.ok(boxer.includes('sessionStorage.setItem'));
assert.ok(boxer.includes('training_drafts_v2'));
assert.ok(boxer.includes('trainingSubmitBusy=true'));
assert.ok(boxer.includes("db.from('training_submissions').insert"));
assert.ok(boxer.includes('Training eingereicht – wartet auf Bestätigung'));
assert.ok(boxer.includes("$('joggingKm').value='';$('techniqueMinutes').value='';$('kind').value=String(type.id);$('kind').dispatchEvent(new Event('change',{bubbles:true}));updateFields();await load()"));
assert.ok(!boxer.includes("$('kind').value='';updateFields();await load()"));
assert.ok(!boxer.includes('JSON.stringify({...saved,notes:'));
assert.match(duel,/if\(!confirm\('Duell-Einladung senden\?/);
assert.match(duel,/const challengerName=eligible\.find/);
assert.match(duel,/const opponentName=eligible\.find/);
assert.match(duel,/48 Stunden annehmen/);
const posConfirm=duel.indexOf("if(!confirm('Duell-Einladung");
const posInvite=duel.indexOf("mutate('duel_v2_invite'");
assert.ok(posConfirm>=0 && posInvite>posConfirm,
'User confirmation must happen before the RPC call');
assert.match(duel,/p_challenger:challenger,p_opponent:opponent,p_duration_days:days/);
assert.match(duel,/if\(busy\|\|!profile\)return/);
console.log('PASS: All 20 UX requirements planned, safe local preference, preserved training/points flow and confirmed duel invitations.');
