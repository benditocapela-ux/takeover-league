-- ISOLATED SUPABASE TEST ONLY: underdog defeats higher-rank boxer.
-- Confirms +150 / -50 once, rank captured at acceptance, no duplicated payouts.
begin;
update public.league_feature_flags set is_enabled=true where feature_key='duels';
select set_config('d.admin',(select auth_user_id::text from public.profiles where role='admin' and is_active and auth_user_id is not null limit 1),true);
select set_config('d.low',(select id::text from public.profiles where role='boxer' and is_active and auth_user_id is not null order by id limit 1),true);
select set_config('d.high',(select id::text from public.profiles where role='boxer' and is_active and auth_user_id is not null order by id desc limit 1),true);
select set_config('d.started',(now()-interval '8 days')::text,true);
insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
values(current_setting('d.high')::uuid,null,0,5000,'trainer_bonus','TEST only favourite rank',current_date-20);
with x as (
 insert into public.league_duels(challenger_id,opponent_id,status,duration_days,created_by,initiated_by_coach,invited_at,expires_at)
 values(current_setting('d.low')::uuid,current_setting('d.high')::uuid,'pending',7,
   (select id from public.profiles where auth_user_id=current_setting('d.admin')::uuid),
   true,now()-interval '9 days',now()-interval '8 days')
 returning id
) select set_config('d.duel',id::text,true) from x;
update public.league_duels set status='active',
 accepted_at=current_setting('d.started')::timestamptz,
 ends_at=current_setting('d.started')::timestamptz+interval '7 days'
where id=current_setting('d.duel')::uuid;
do $t$ begin
if (select count(*) from public.league_duel_rank_snapshots_v21 where duel_id=current_setting('d.duel')::uuid)<>2
then raise exception 'Expected 2 rank snapshots at acceptance';end if;
if (select rank_index from public.league_duel_rank_snapshots_v21 where duel_id=current_setting('d.duel')::uuid and boxer_id=current_setting('d.low')::uuid)
 >= (select rank_index from public.league_duel_rank_snapshots_v21 where duel_id=current_setting('d.duel')::uuid and boxer_id=current_setting('d.high')::uuid)
then raise exception 'Test fixture did not create different rank tiers';end if;
end$t$;
with x as (
 insert into public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
 values(current_setting('d.low')::uuid,(select id from public.training_types where is_active limit 1),
 current_date-4,'approved',now()-interval '4 days') returning id
) select set_config('d.sub',id::text,true) from x;
insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
values(current_setting('d.low')::uuid,current_setting('d.sub')::uuid,50,50,'training','TEST only duel underdog win',current_date-4);
select set_config('request.jwt.claim.sub',current_setting('d.admin'),true);
set local role authenticated;
select public.duel_v2_reconcile(current_setting('d.duel')::uuid);
select public.duel_v2_reconcile(current_setting('d.duel')::uuid);
reset role;
do $test$ begin
if (select count(*) from public.league_duel_exp_ledger where duel_id=current_setting('d.duel')::uuid)<>2
then raise exception 'Expected two duel EXP ledgers';end if;
if (select awarded_exp from public.league_duel_exp_ledger where duel_id=current_setting('d.duel')::uuid and boxer_id=current_setting('d.low')::uuid)<>150
then raise exception 'Underdog winner did not receive 150 EXP';end if;
if (select awarded_exp from public.league_duel_exp_ledger where duel_id=current_setting('d.duel')::uuid and boxer_id=current_setting('d.high')::uuid)<>-50
then raise exception 'Defeated favorite did not receive -50 EXP';end if;
if (select count(*) from public.point_transactions t where t.category='duel_exp'
 and t.description='Duel reward: '||current_setting('d.duel'))<>2
then raise exception 'Duel payout double-awarded';end if;
end$test$;
rollback;