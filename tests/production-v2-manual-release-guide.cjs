const assert = require('node:assert/strict');
const fs = require('node:fs');
const read = path => fs.readFileSync(path, 'utf8');

const manual = read('docs/PRODUKTIV_RELEASE_SQL_EDITOR_ANLEITUNG.md');
const expectedOrder = [
  '20261018_restrict_achievement_recalculation.sql',
  '20261018131000_coach_challenges_v2.sql',
  '20261018133000_duels_v2.sql',
  'release_postflight_read_only.sql',
  'activate_v2_only_after_freigeben.sql',
  'SQL ERLEDIGT'
];
let offset = -1;
for (const item of expectedOrder) {
  const next = manual.indexOf(item, offset + 1);
  assert.ok(next > offset, 'Missing or out-of-order release step: ' + item);
  offset = next;
}
assert.match(manual, /iqarjivcrddcixrvqbfb/, 'Must identify production project');
assert.match(manual, /ohne Backup/i, 'User-approved backup waiver must be explicit');
assert.match(manual, /bei jedem Fehler/i, 'Abort-on-error must be documented');
assert.match(manual, /emergency_disable_v2_flags_only.sql/, 'Must describe non-destructive emergency off switch');
assert.match(manual, /noch nicht installiert/i, 'Manual instructions must not claim deployed');

for (const path of [
 'supabase/production-prep/20261018_restrict_achievement_recalculation.sql',
 'supabase/migrations/20261018131000_coach_challenges_v2.sql',
 'supabase/migrations/20261018133000_duels_v2.sql',
 'supabase/production-prep/activate_v2_only_after_freigeben.sql'
]) {
 const sql = read(path);
 assert.equal((sql.match(/^BEGIN;$/gm) || []).length, 1, 'Expected one atomic BEGIN for ' + path);
 assert.equal((sql.match(/^COMMIT;$/gm) || []).length, 1, 'Expected one atomic COMMIT for ' + path);
 assert.doesNotMatch(sql, /\bsb_secret_|\bservice_role\s*=\s*['"]/i, 'Cannot ship a server-side API secret');
}
const challenge = read('supabase/migrations/20261018131000_coach_challenges_v2.sql');
const duel = read('supabase/migrations/20261018133000_duels_v2.sql');
assert.match(challenge, /NOTIFY pgrst, 'reload schema'/);
assert.match(duel, /NOTIFY pgrst, 'reload schema'/);
assert.match(challenge, /is_enabled IS FALSE/);
assert.match(duel, /is_enabled IS FALSE/);
console.log('Manual release guide checks passed: SQL order, atomicity, production project, no backup waiver and abort gates.');
