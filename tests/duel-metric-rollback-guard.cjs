'use strict';
// Run after metric concurrency creates owned synthetic contracts in a disposable database.
const fs=require('node:fs');const assert=require('node:assert/strict');const {execFileSync}=require('node:child_process');
assert.match(process.env.PGDATABASE||'',/^league21_replay_[a-z0-9_]+$/);
const psql=process.env.PSQL||'psql';const args=['-X','-A','-t','-v','ON_ERROR_STOP=1'];
const run=sql=>execFileSync(psql,[...args,'-c',sql],{encoding:'utf8',timeout:15000}).trim();
const witness=`select md5(jsonb_build_object('duels',(select jsonb_agg(to_jsonb(d) order by id) from public.league_duels d),
'ledger',(select jsonb_agg(to_jsonb(l) order by duel_id,boxer_id) from public.league_duel_exp_ledger l),
'tx',(select jsonb_agg(to_jsonb(t) order by id) from public.point_transactions t))::text)`;
assert.ok(Number(run("select count(*) from public.league_duels where scoring_contract is not null"))>0,'Needs synthetic contracted duels');
const before=run(witness);let rejected=false;
try{
 execFileSync(psql,args,{input:fs.readFileSync('supabase/production-prep/rollback_20261102095422_duel_metric_contracts_disabled.sql','utf8'),encoding:'utf8',stdio:['pipe','pipe','pipe'],timeout:15000});
}catch(error){assert.match(String(error.stderr),/Metric contracts, configuration or trusted receipts exist/);rejected=true;}
assert.ok(rejected,'Rollback must reject stored agreements');
assert.equal(run(witness),before,'Rejected rollback changed results/payouts');
assert.equal(run("select to_regprocedure('public.duel_v3_options()') is not null"),'t');
console.log('PASS populated metric rollback refuses to discard agreements and preserves results/payouts.');
