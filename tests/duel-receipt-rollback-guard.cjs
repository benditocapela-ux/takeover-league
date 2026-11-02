'use strict';
// Run before persistent metric concurrency fixtures, after transaction suites have rolled back.
const fs=require('node:fs');const assert=require('node:assert/strict');const {execFileSync}=require('node:child_process');
assert.match(process.env.PGDATABASE||'',/^league21_replay_[a-z0-9_]+$/);
const psql=process.env.PSQL||'psql';const args=['-X','-A','-t','-v','ON_ERROR_STOP=1'];
const run=sql=>execFileSync(psql,[...args,'-c',sql],{encoding:'utf8',timeout:15000}).trim();
assert.equal(run('select count(*) from public.league_duels where scoring_contract is not null'),'0','Receipt-only guard requires no existing v3 agreement');
const before=run('select count(*) from public.training_submissions');
const seed=`BEGIN;
insert into public.training_submissions(boxer_id,training_type_id,training_date,status,notes)
values('11111111-1111-4111-8111-111111111111',1,current_date,'pending','Receipt rollback guard fixture');
`;
let rejected=false;
try{
 // The rollback's nested BEGIN produces a warning; its guard must throw before any commit/drop.
 execFileSync(psql,args,{input:seed+fs.readFileSync('supabase/production-prep/rollback_20261102095422_duel_metric_contracts_disabled.sql','utf8'),encoding:'utf8',stdio:['pipe','pipe','pipe'],timeout:15000});
}catch(error){assert.match(String(error.stderr),/trusted receipts exist/);rejected=true;}
assert.ok(rejected,'A real server receipt must prevent destructive rollback without any metric agreement');
assert.equal(run('select count(*) from public.training_submissions'),before,'Failed rollback transaction did not clean up its synthetic insert');
assert.equal(run("select exists(select 1 from information_schema.columns where table_schema='public' and table_name='training_submissions' and column_name='server_received_at')"),'t');
console.log('PASS receipt-only rollback refuses to discard trusted evidence and leaves existing data/schema unchanged.');
