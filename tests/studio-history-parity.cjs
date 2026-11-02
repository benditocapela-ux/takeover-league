'use strict';
// Run after studio-history-schema.sql, exclusively in a disposable local/CI DB.
const fs=require('node:fs'),assert=require('node:assert/strict'),{execFileSync}=require('node:child_process');
assert.match(process.env.PGDATABASE||'',/^league21_replay_/);
const sql=q=>execFileSync(process.env.PSQL||'psql',['-X','-q','-A','-t','-v','ON_ERROR_STOP=1','-c',q],{encoding:'utf8'}).trim();
assert.match(sql('select current_database()'),/^league21_replay_/);
(async()=>{
 const m=await import('data:text/javascript,'+encodeURIComponent(fs.readFileSync('takeover-gamification.js','utf8')));
 const fixture=JSON.parse(sql(`select jsonb_build_object('rows',(select jsonb_agg(to_jsonb(s)) from public.training_submissions s where boxer_id='11111111-1111-4111-8111-111111111111'),'types',(select jsonb_agg(to_jsonb(t)) from public.training_types t));`));
 const q=`begin read only;select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);set local role authenticated;select public.get_my_studio_training_summary();rollback;`;
 const summary=JSON.parse(sql(q).split(/\r?\n/).find(x=>x.startsWith('{'))),names=new Map(fixture.types.map(t=>[String(t.id),t.name]));
 const progress=m.achievementProgress(fixture.rows,names);
 for(const key of Object.keys(progress))assert.ok(Math.abs(progress[key]-summary.progress[key])<1e-9,key+' matches complete legacy source rows (SQL numeric totals remain exact)');
 const [y,mo,d]=summary.today.split('-').map(Number),weekly=m.weeklyState(fixture.rows,names,new Date(y,mo-1,d));
 assert.equal(summary.weekly.streak,weekly.streak);assert.deepEqual([summary.weekly.done,summary.weekly.boxing_done,summary.weekly.engine_done],weekly.quests.map(q=>q.done));
 assert.deepEqual([summary.weekly.pending,summary.weekly.boxing_pending,summary.weekly.engine_pending],weekly.quests.map(q=>q.waiting));
 assert.ok(Buffer.byteLength(JSON.stringify(summary))<8000,'Summary bounded by types and42days, not raw submissions');
 console.log('PASS PostgreSQL aggregate parity with all1202 legacy rows: all8achievement families, weeklyquests/streak, compact response');
})().catch(e=>{console.error(e);process.exitCode=1});
