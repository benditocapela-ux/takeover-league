'use strict';
// Actual PG two-session closure; use only the dedicated period-close fixture DB.
const assert=require('node:assert/strict'),{spawn,execFileSync}=require('node:child_process');
assert.match(process.env.PGDATABASE||'',/^league21_replay_[a-z0-9_]+$/);
const psql=process.env.PSQL||'psql',args=['-X','-q','-A','-t','-v','ON_ERROR_STOP=1'];
const run=sql=>execFileSync(psql,[...args,'-c',sql],{encoding:'utf8',timeout:15000}).trim();
const actor=id=>`select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-00000000000${id}',true);set local role authenticated;`;
const revision=run(`begin;${actor(2)}select public.league_period_close_preview('month','2026-10')->>'revision';rollback;`).split(/\r?\n/).at(-1);
assert.match(revision,/^[a-f0-9]{32}$/);
const close=`select public.league_period_close_confirm('month','2026-10',true,'${revision}');`;
function session(commands,output){const p=spawn(psql,[...args,...commands.flatMap(c=>['-c',c])]);let stdout='',stderr='';return new Promise((resolve,reject)=>{
 const timer=setTimeout(()=>{p.kill();reject(Error('PG timeout'))},15000);p.stdout.on('data',c=>{stdout+=c;output?.(stdout)});p.stderr.on('data',c=>stderr+=c);p.on('error',reject);p.on('exit',c=>{clearTimeout(timer);c?reject(Error(stderr)):resolve(stdout)});
})}
(async()=>{let mark;const held=new Promise(r=>mark=r);const a=session(['begin',actor(2),close,"select 'LOCK_HELD'",'select pg_sleep(2)','commit'],text=>{if(text.includes('LOCK_HELD'))mark()});
 await Promise.race([held,a.then(()=>{throw Error('Lock not observed')})]);const start=Date.now();const b=session(['begin',actor(7),close,'commit']);const [first,second]=await Promise.all([a,b]);
 const json=s=>JSON.parse(s.split(/\r?\n/).find(l=>l.startsWith('{')));assert.equal(json(first).status,'closed');assert.equal(json(second).unchanged,true);assert.ok(Date.now()-start>=1000);
 const state=JSON.parse(run(`select jsonb_build_object('closures',(select count(*) from league_archive_private.period_closures),'rows',(select count(*) from league_archive_private.month_results),'notices',(select count(*) from public.boxer_notifications),'transactions',(select count(*) from public.point_transactions))`));
 assert.deepEqual(state,{closures:1,rows:2,notices:2,transactions:6});
 console.log('PASS real PG concurrent coach/admin month close: one immutable snapshot, two recipient events, zero payouts.');
})().catch(e=>{console.error(e);process.exitCode=1});
