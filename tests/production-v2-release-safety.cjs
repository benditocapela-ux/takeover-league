const fs=require('node:fs');
const assert=require('node:assert/strict');
const read=path=>fs.readFileSync(path,'utf8');
const release=read('docs/v2-release-verification-2026-10-18.md');
const baseline=read('supabase/production-prep/production_baseline_read_only.sql');
const guard=read('supabase/production-prep/20261018_restrict_achievement_recalculation.sql');
const ignore=read('.gitignore');
const cleanBaseline=baseline.split('\n').filter(s=>!s.trim().startsWith('--')).join('\n').replace(/'(?:EXECUTE|SELECT|INSERT|UPDATE|DELETE)'/g,"'privilege-name'");
assert.match(cleanBaseline,/^\s*SELECT\s+/,'production baseline must be SELECT-only');
assert.doesNotMatch(cleanBaseline,/\b(?:INSERT|UPDATE|DELETE|ALTER|TRUNCATE|DROP|CREATE|DO|CALL|COPY|EXECUTE)\b/i,
 'read-only production preflight must not mutate data or privileges');
for(const metric of ['point_total','exp_total','profile_count','point_transactions','training_submissions','v2_rpcs_present','v2_tables_present','v2_enabled_flags'])
 assert.ok(baseline.includes("'"+metric+"'"),'missing baseline metric '+metric);
assert.match(guard,/REVOKE EXECUTE ON FUNCTION public\.recalculate_boxer_achievements_v2\(uuid\)/);
assert.match(guard,/FROM PUBLIC, anon, authenticated/);
assert.match(guard,/has_function_privilege\('service_role'/);
assert.match(guard,/public\._award_achievements_on_approval/);
assert.match(guard,/pg_catalog\.pg_trigger/);
assert.doesNotMatch(guard,/\bCASCADE\b|DROP FUNCTION|DROP TABLE/i);
assert.match(read('tests/production-v2-achievements-hardening.sql'),/legitimate approval trigger/i);
for(const file of ['challenges.html','duels.html']){
 const html=read(file);
 assert.match(html,/window\.TAKEOVER_(?:CHALLENGES|DUELS)_V2_ENABLED=true/,'production frontend release flag must be enabled: '+file);
 assert.doesNotMatch(html,/service_role|sb_secret_/i,'secret key leaked into frontend: '+file);
}
assert.match(ignore,/\.env/);
assert.match(ignore,/takeover-private-backup/);
assert.match(ignore,/\*\.dump/);
assert.match(release,/\*\*Status: NO-GO/);
assert.match(release,/Free/);
assert.match(release,/ROLLBACK/);
assert.match(release,/\$HOME\/takeover-private-backup/,'backup path must be outside the Git repo');
assert.match(read('supabase/production-prep/README.md'),/NOT APPLIED/);
for(const path of ['release_preflight_read_only.sql','release_postflight_read_only.sql']){
 const sql=read('supabase/production-prep/'+path);
 const stripped=sql.split('\n').filter(s=>!s.trim().startsWith('--')).join('\n').replace(/'(?:EXECUTE|SELECT|INSERT|UPDATE|DELETE)'/g,"'privilege-name'");
 assert.match(stripped,/^\s*(?:WITH|SELECT)\s+/i,path+' must be a read-only SELECT');
 assert.doesNotMatch(stripped,/\b(?:INSERT|UPDATE|DELETE|ALTER|TRUNCATE|DROP|CREATE|DO|CALL|COPY|EXECUTE)\b/i,
   path+' must never modify live state');
}
assert.match(read('supabase/production-prep/release_preflight_read_only.sql'),/ready_for_controlled_release/);
const post=read('supabase/production-prep/release_postflight_read_only.sql');
assert.match(post,/release_integrity_passed/);
assert.match(post,/protected_authenticated_rpcs=23/);
assert.match(post,/protected_authenticated_rpcs=23 \+ CASE WHEN pg_catalog\.to_regprocedure/);
assert.match(post,/v2_tables=7 AND rls_protected_tables=7/);
assert.match(post,/invalid_challenge_exp_ledgers=0/);
assert.match(post,/invalid_duel_exp_ledgers=0/);
const activation=read('supabase/production-prep/activate_v2_only_after_freigeben.sql');
const emergency=read('supabase/production-prep/emergency_disable_v2_flags_only.sql');
assert.match(activation,/BEGIN;/);
assert.match(activation,/COMMIT;/);
assert.match(activation,/expected_protected_rpc := 23 \+ CASE WHEN admin_challenge_edit THEN 1 ELSE 0 END/);
assert.match(activation,/protected_tables<>7/);
assert.match(activation,/Achievement EXP security patch has not been applied/);
assert.match(activation,/UPDATE public\.league_feature_flags/);
assert.doesNotMatch(activation,/\b(?:UPDATE|DELETE|TRUNCATE)\s+(?:FROM\s+)?public\.(?!league_feature_flags\b)/i,
 'V2 activation may only write to feature flags');
assert.match(emergency,/UPDATE public\.league_feature_flags/);
assert.match(emergency,/SET is_enabled=false/);
assert.doesNotMatch(emergency,/\b(?:DELETE|TRUNCATE|DROP)\b/i,
 'emergency off-switch must preserve all boxer data and EXP');
const releaseRunbook=read('docs/RELEASE_NACH_FREIGEBEN.md');
assert.match(releaseRunbook,/release_preflight_read_only\.sql/);
assert.match(releaseRunbook,/release_postflight_read_only\.sql/);
assert.match(releaseRunbook,/activate_v2_only_after_freigeben\.sql/);
assert.match(releaseRunbook,/emergency_disable_v2_flags_only\.sql/);
assert.match(releaseRunbook,/«FREIGEBEN»/,'Release must require explicit final approval');
assert.match(releaseRunbook,/ohne Backup/i,'Conscious no-backup risk decision must be documented');
assert.match(releaseRunbook,/release_coach_challenges_v2/);
assert.match(releaseRunbook,/release_duels_v2/);
assert.match(releaseRunbook,/hosted-v2-live-release-check/);
const postDeploy=read('tests/hosted-v2-live-release-check.cjs');
for(const page of ['challenges.html','duels.html']){
 assert.ok(postDeploy.includes(page),'Post-release HTTP check misses '+page);
}
for(const file of ['boxer.html','coach.html']){
 const html=read(file);
 assert.ok(file==='coach.html'?html.includes('Challenges &amp; Boxer-Duelle'):(html.includes('id="boxerTaskCenter"')&&html.includes('href="./challenges.html"')&&html.includes('href="./duels.html"')),file+' missing neutral V2 navigation');
 assert.ok(!html.includes('Coach Challenges V2 – in Vorbereitung'),file+' contains stale launch text');
}
console.log('Release safety guards passed: read-only baseline, protected Achievement revoke, disabled V2 frontends and private backups');
