'use strict';
// Compare real page DOM hooks and known RPC literals with the archived pre-redesign
// sources. This is source-contract verification, not a login or transaction E2E test.
const fs=require('node:fs');const assert=require('node:assert/strict');
const baseline=require('./redesign-preserved-contracts.json');
let ids=0, rpcCount=0;
for(const [path,b] of Object.entries(baseline)){
 const s=fs.readFileSync(path,'utf8');
 const gotIds=[...s.matchAll(/\bid\s*=\s*["']([^"']+)["']/gi)].map(x=>x[1]);
 const gotRpc=[...new Set([...s.matchAll(/\brpc\s*\(\s*["']([^"']+)["']/gi)].map(x=>x[1]))].sort();
 // Keep every pre-existing hook in the original order. New semantic tab IDs
 // are allowed only for the five accessible guest navigation tabs.
 const originalIds=gotIds.filter(id=>b.ids.includes(id));
 assert.deepEqual(originalIds,b.ids,`${path}: a pre-existing DOM hook changed`);
 const addedIds=gotIds.filter(id=>!b.ids.includes(id));
 const allowedAdded=path==='guest.html'
  ? ['guest-tab-overview','guest-tab-ranking','guest-tab-challenges','guest-tab-duels','guest-tab-history']
  : path==='admin.html' ? ['showArchived'] : [];
 assert.deepEqual(addedIds,allowedAdded,`${path}: unexpected additional DOM ID`);
 const originalRpc=gotRpc.filter(rpc=>b.rpc.includes(rpc));
 assert.deepEqual(originalRpc,b.rpc,`${path}: a pre-existing RPC literal changed`);
 const addedRpc=gotRpc.filter(rpc=>!b.rpc.includes(rpc));
 const allowedRpc={'admin.html':['admin_list_profile_archive_state'],'coach.html':['coach_list_training_history'],
  'league-manager.html':['league_v21_admin_delete_global_draft','league_v21_admin_publish_global_challenge','league_v21_admin_update_global_draft',
   'league_v21_archive_goal','league_v21_complete_goal','league_v21_record_goal_progress'],
  'goals.html':['league_v21_archive_goal'],
  'arena.html':['league_v21_arena_cancel']};
 assert.deepEqual(addedRpc,allowedRpc[path]||[],`${path}: unexpected additional RPC literal`);
 const choiceCardPages=new Set(['arena.html','boxer.html','boxer-compare.html','challenges.html','duels.html','goals.html','league-manager.html','league-challenges.html']);
 const allowedScriptAdditions=(choiceCardPages.has(path)?1:0)+(path==='boxer.html'?1:0);
 assert.equal((s.match(/<script\b/gi)||[]).length,b.scriptCount+allowedScriptAdditions,`${path}: unexpected script change`);
 assert.match(s,/takeover-redesign\.css/,`${path}: must import production stylesheet`);
 ids+=gotIds.length;rpcCount+=gotRpc.length;
}
const nav=fs.readFileSync('takeover-navigation.js','utf8');
assert.match(nav,/role==='admin'/);assert.match(nav,/ROLE_NAV/);assert.match(nav,/adminEntry\.hidden=true/);
const css=fs.readFileSync('takeover-redesign.css','utf8');
assert.match(css,/--gold:#f2c14e/);assert.match(css,/--ok:#5fb27f/);
assert.match(css,/prefers-reduced-motion:reduce/);assert.match(css,/safe-area-inset-bottom/);
assert.match(css,/min-height:44px/);
console.log(`PASS: ${Object.keys(baseline).length} pages, ${ids-5} preserved DOM hooks + 5 guest accessibility IDs, ${rpcCount} RPC literals, role-navigation contract intact`);
