const fs=require('node:fs');
const assert=require('node:assert/strict');
const root='supabase/production-prep/';
const parts=[
'20261018_allow_coach_role.sql',
'20261018_extend_transaction_categories.sql',
'20261018_v2_feature_flags_disabled.sql',
'20261018_coach_challenges_v2_schema.sql',
'20261018_coach_challenges_v2_rpc_core.sql',
'20261018_coach_challenges_v2_rpc_review.sql'
];
const bundle=fs.readFileSync('supabase/migrations/20261018131000_coach_challenges_v2.sql','utf8');
for(const file of parts){
 const content=fs.readFileSync(root+file,'utf8').replace(/^BEGIN;\s*$/gm,'').replace(/^COMMIT;\s*$/gm,'').trim();
 assert.ok(bundle.includes(content),'Atomic production migration is outdated compared with '+file);
}
assert.equal((bundle.match(/^BEGIN;$/gm)||[]).length,1,'release migration must have one transaction');
assert.equal((bundle.match(/^COMMIT;$/gm)||[]).length,1,'release migration must have one transaction');
const api=[...bundle.matchAll(/CREATE OR REPLACE FUNCTION public\.(coach_challenge_v2_[a-z_]+)\(/g)].map(x=>x[1]);
assert.equal(api.length,17,'all 17 backend RPCs must be bundled');
assert.equal(new Set(api).size,17,'RPC names must be unique');
assert.match(bundle,/league_private\.coach_v2_actor/,'private actor authorization required');
assert.match(bundle,/FROM PUBLIC, anon/,'public/anonymous EXECUTE revocation required');
assert.match(bundle,/\('coach_challenges','Coach Challenges V2',false\)/,'challenge flag must default disabled');
assert.doesNotMatch(bundle,/test_only_missing_base_tables/,'test-only schema must never ship');
const duels=fs.readFileSync('supabase/migrations/20261018133000_duels_v2.sql','utf8');
const duelRPCs=[...duels.matchAll(/CREATE OR REPLACE FUNCTION public\.(duel_v2_[a-z_]+)\(/g)].map(x=>x[1]);
assert.equal(duelRPCs.length,6,'six V2 duel backend RPCs must be bundled');
assert.equal(new Set(duelRPCs).size,6,'duel RPC names must be unique');
for(const table of ['league_duels','league_duel_events','league_duel_exp_ledger']){
 assert.ok(duels.includes('CREATE TABLE public.'+table),'missing duel table '+table);
 assert.ok(duels.includes('ALTER TABLE public.'+table+' ENABLE ROW LEVEL SECURITY;'),'RLS missing '+table);
}
assert.match(duels,/feature_key='duels' AND is_enabled IS FALSE/,'duel rollout must fail closed');
assert.match(duels,/FROM PUBLIC,anon/,'duel functions must revoke anonymous execution');
assert.doesNotMatch(duels,/test_only_missing_base_tables/,'test-only tables must not ship');
const duelPage=fs.readFileSync('duels.html','utf8');
assert.match(duelPage,/TAKEOVER_DUELS_V2_ENABLED=false/,'duel production frontend must remain disabled');
assert.match(duelPage,/iqarjivcrddcixrvqbfb/,'duel production frontend must use live project only');
console.log('Atomic production migration matches all six modules and includes all 17 protected RPCs');
