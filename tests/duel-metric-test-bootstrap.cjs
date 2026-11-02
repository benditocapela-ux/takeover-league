'use strict';
// Local/CI disposable fixture only. Reuses real historical RPC bodies without copying them.
const fs=require('node:fs');
const assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
assert.match(process.env.PGDATABASE||'',/^league21_replay_[a-z0-9_]+$/);
const psql=process.env.PSQL||'psql';
const args=['-X','-v','ON_ERROR_STOP=1'];
const sql=input=>execFileSync(psql,args,{input,encoding:'utf8',timeout:30000});
assert.match(sql('select current_database();'),/league21_replay_/);
function definition(file,name){
 const source=fs.readFileSync(file,'utf8');
 const start=source.indexOf('CREATE OR REPLACE FUNCTION '+name+'(');
 assert.ok(start>=0,`Missing fixture source ${name}`);
 const part=source.slice(start), delimiter=part.match(/AS\s+(\$[a-z_]*\$)/i);
 assert.ok(delimiter,`Missing function delimiter ${name}`);
 const end=part.indexOf(delimiter[1]+';',delimiter.index+delimiter[0].length);
 assert.ok(end>0,`Missing function end ${name}`);
 return part.slice(0,end+delimiter[1].length+1);
}
sql(`alter table public.profiles add column if not exists is_listed boolean not null default true;
alter table public.league_duel_events add column if not exists boxer_id uuid references public.profiles(id);
create unique index if not exists league_duels_one_pending_per_pair on public.league_duels
 (least(challenger_id,opponent_id),greatest(challenger_id,opponent_id)) where status='pending';
create unique index if not exists league_duels_one_active_per_pair on public.league_duels
 (least(challenger_id,opponent_id),greatest(challenger_id,opponent_id)) where status='active';
alter table public.league_duels enable row level security;
revoke all on public.league_duels from public,anon,authenticated;
insert into public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at,notes)
 values('40000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111',1,'2000-01-01','rejected','2000-01-01T12:00:00Z','Historical receipt fixture')
 on conflict(id) do nothing;
${definition('supabase/migrations/20261018133000_duels_v2.sql','public.duel_v2_invite')}
${definition('supabase/migrations/20261018133000_duels_v2.sql','public.duel_v2_respond')}
revoke all on function public.duel_v2_invite(uuid,uuid,integer),public.duel_v2_respond(uuid,boolean) from public,anon,authenticated;
grant execute on function public.duel_v2_invite(uuid,uuid,integer),public.duel_v2_respond(uuid,boolean) to authenticated;
${definition('supabase/migrations/20261027120000_gamification_fairness_and_notifications.sql','league_v21_private.public_display_name')}
revoke all on function league_v21_private.public_display_name(uuid) from public,anon,authenticated;
`);
console.log('PASS metric fixture uses real v2 invite/respond and public-name helper sources.');
