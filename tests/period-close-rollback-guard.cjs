'use strict';
const assert=require('node:assert/strict'),{spawnSync,execFileSync}=require('node:child_process');
assert.match(process.env.PGDATABASE||'',/^league21_replay_[a-z0-9_]+$/);
const psql=process.env.PSQL||'psql',args=['-X','-q','-A','-t','-v','ON_ERROR_STOP=1'];
const before=execFileSync(psql,[...args,'-c','select count(*) from league_archive_private.period_closures'],{encoding:'utf8'}).trim();assert.ok(Number(before)>0);
const attempt=spawnSync(psql,[...args,'-f','supabase/production-prep/rollback_20261102095858_period_close_preview_snapshot.sql'],{encoding:'utf8'});
assert.notEqual(attempt.status,0);assert.match(attempt.stderr,/Official period records exist: destructive rollback forbidden/);
assert.equal(execFileSync(psql,[...args,'-c','select count(*) from league_archive_private.period_closures'],{encoding:'utf8'}).trim(),before);
console.log('PASS populated official snapshots prevent destructive rollback and remain intact.');
