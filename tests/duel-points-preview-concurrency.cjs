'use strict';
// Real PostgreSQL two-session test. Requires the disposable schema fixture first.
// PGDATABASE must start league21_replay_. PSQL may specify a portable psql binary.
const assert = require('node:assert/strict');
const { spawn, execFileSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
assert.match(process.env.PGDATABASE || '', /^league21_replay_[a-z0-9_]+$/);
const psql = process.env.PSQL || 'psql';
const metric = process.env.DUEL_TEST_METRIC || 'points';
const reward = process.env.DUEL_TEST_REWARD || 'none';
assert.ok(['points','training_count'].includes(metric));
assert.ok(['none','ranked_v21'].includes(reward));
const api = metric === 'points' ? 'duel_v2' : 'duel_v3';
const cli = ['-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1'];
const run = sql => execFileSync(psql, [...cli, '-c', sql], { encoding: 'utf8', timeout: 15000 }).trim();
assert.match(run('select current_database()'), /^league21_replay_/);
const duel = randomUUID(), a = randomUUID(), b = randomUUID();
const pa = randomUUID(), pb = randomUUID(), ca = randomUUID(), cb = randomUUID();
const authA = randomUUID(), authB = randomUUID();
run(`insert into public.profiles(id,auth_user_id,display_name,role) values
 ('${pa}','${a}','Synthetic Concurrent A','boxer'),('${pb}','${b}','Synthetic Concurrent B','boxer'),
 ('${ca}','${authA}','Synthetic Coach A','coach'),('${cb}','${authB}','Synthetic Coach B','coach');
 ${metric === 'points' ? `insert into public.league_duels(id,challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
 values('${duel}','${pa}','${pb}','active',7,now()-interval '8 days',now()-interval '1 day');` :
 `insert into public.league_duels(id,challenger_id,opponent_id,status,duration_days,scoring_metric,scoring_training_type_id,scoring_contract)
 values('${duel}','${pa}','${pb}','pending',7,'training_count',(select min(id) from public.training_types where is_active),
 jsonb_build_object('version',3,'metric','training_count','label','Synthetic concurrent count','unit','Trainings',
  'visibility','participants','reward_rule','${reward}','reward_label','Explicit isolated test agreement',
  'timezone','Europe/Zurich','time_rule','next_zurich_midnight_full_days'));
 update public.league_duels set status='active',accepted_at=now()-interval '8 days',ends_at=now()-interval '1 day' where id='${duel}';`}`);
const asActor = auth => `select set_config('request.jwt.claim.sub','${auth}',true); set local role authenticated;`;
const revision = run(`begin; ${asActor(authA)} select public.${api}_close_preview('${duel}')->>'revision'; rollback;`).split(/\r?\n/).at(-1);
assert.match(revision, /^[a-f0-9]{32}$/);
const close = `select public.${api}_close_confirm('${duel}',true,'${revision}');`;
function session(sql, onOutput) {
  const commands = (Array.isArray(sql) ? sql : [sql]).flatMap(statement => ['-c', statement]);
  const child = spawn(psql, [...cli, ...commands], { stdio: ['ignore', 'pipe', 'pipe'] });
  let stdout = '', stderr = '';
  const complete = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { child.kill(); reject(Error('PostgreSQL session timed out')); }, 15000);
    child.stdout.on('data', chunk => { stdout += chunk; onOutput?.(stdout); });
    child.stderr.on('data', chunk => { stderr += chunk; });
    child.on('error', err => { clearTimeout(timer); reject(err); });
    child.on('exit', code => { clearTimeout(timer); code === 0 ? resolve(stdout) : reject(Error(stderr || `psql exit ${code}`)); });
  });
  return complete;
}
(async () => {
  let resolveLocked;
  const locked = new Promise(resolve => { resolveLocked = resolve; });
  // Separate commands flush the marker before pg_sleep; a single -c buffers all results.
  const first = session(['begin', asActor(authA), close, "select 'LOCK_HELD'", 'select pg_sleep(2)', 'commit'],
    output => { if (output.includes('LOCK_HELD')) resolveLocked(); });
  await Promise.race([locked, first.then(() => { throw Error('Lock marker not observed'); })]);
  const started = Date.now();
  const second = session(`begin; ${asActor(authB)} ${close} commit;`);
  const [one, two] = await Promise.all([first, second]);
  const elapsed = Date.now() - started;
  const json = output => JSON.parse(output.split(/\r?\n/).find(line => line.startsWith('{')));
  assert.equal(json(one).outcome, 'settled');
  assert.equal(json(two).outcome, 'preview_changed');
  assert.equal(json(two).preview.status, 'settled');
  assert.equal(json(two).unchanged, true);
  const paid = metric === 'points' || reward === 'ranked_v21';
  assert.equal(json(two).bookings.length, paid ? 2 : 0);
  assert.ok(elapsed >= 1000, `Second session did not wait on row locks (${elapsed}ms)`);
  const totals = JSON.parse(run(`select jsonb_build_object(
    'ledger',(select count(*) from public.league_duel_exp_ledger where duel_id='${duel}'),
    'exp',(select sum(awarded_exp) from public.league_duel_exp_ledger where duel_id='${duel}'),
    'tx',(select count(*) from public.point_transactions where category='duel_exp' and description='Duel reward: ${duel}'),
    'events',(select count(*) from public.league_duel_events where duel_id='${duel}' and event_type='settled'));`));
  assert.deepEqual(totals, paid ? { exp: 100, tx: 2, events: 1, ledger: 2 } : { exp: null, tx: 0, events: 1, ledger: 0 });
  if(metric !== 'points') assert.equal(run(`select count(*) from public.league_public_duel_history_v21 where duel_id='${duel}'`),'0');
  console.log(`PASS real PostgreSQL two-coach ${metric} closure: second session waited ${elapsed}ms, one settlement, ${paid ? 'two existing-rule tie payouts' : 'explicit no-reward contract'}.`);
})().catch(err => { console.error(err.message); process.exitCode = 1; });
