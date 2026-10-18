const fs=require('node:fs');
const assert=require('node:assert/strict');
const read=path=>fs.readFileSync(path,'utf8');
const release=read('docs/v2-release-verification-2026-10-18.md');
const baseline=read('supabase/production-prep/production_baseline_read_only.sql');
const guard=read('supabase/production-prep/20261018_restrict_achievement_recalculation.sql');
const ignore=read('.gitignore');
const cleanBaseline=baseline.split('\n').filter(s=>!s.trim().startsWith('--')).join('\n').replace(/'EXECUTE'/g,"'privilege-name'");
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
 assert.match(html,/window\.TAKEOVER_(?:CHALLENGES|DUELS)_V2_ENABLED=false/,'production must remain disabled: '+file);
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
console.log('Release safety guards passed: read-only baseline, protected Achievement revoke, disabled V2 frontends and private backups');
