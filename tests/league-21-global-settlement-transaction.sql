-- Staging-only transaction rollback: Global challenge reviewed closure, ties and exact one-time prizes.
begin;
select set_config('gc.admin',(select auth_user_id::text from public.profiles where role='admin' and is_active and auth_user_id is not null limit 1),true);
select set_config('gc.one',(select id::text from public.profiles where role='boxer' and is_active and auth_user_id is not null order by id limit 1),true);
select set_config('gc.two',(select id::text from public.profiles where role='boxer' and is_active and auth_user_id is not null order by id desc limit 1),true);
do $t$ begin if current_setting('gc.one')=current_setting('gc.two') then raise exception 'Fixture needs two distinct boxers';end if;end$t$;
with x as (
 insert into public.league_global_challenges_v21(title,metric,target_value,starts_at,ends_at,status,created_by)
 values('TEST global prizes','training_sessions',1,now()-interval '9 days',now()+interval '2 days','active',
  (select id from public.profiles where auth_user_id=current_setting('gc.admin')::uuid)) returning id
) select set_config('gc.challenge',id::text,true) from x;
select set_config('request.jwt.claim.sub',current_setting('gc.admin'),true);
set local role authenticated;
select public.league_v21_admin_set_global_rewards(current_setting('gc.challenge')::uuid,20,30);
reset role;
update public.league_global_challenges_v21 set ends_at=now()-interval '1 day'
 where id=current_setting('gc.challenge')::uuid;
insert into public.league_global_entries_v21(challenge_id,boxer_id,joined_at)
values(current_setting('gc.challenge')::uuid,current_setting('gc.one')::uuid,now()-interval '8 days'),
(current_setting('gc.challenge')::uuid,current_setting('gc.two')::uuid,now()-interval '8 days');
with x as (
 insert into public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
 values(current_setting('gc.one')::uuid,(select id from public.training_types where is_active order by id limit 1),
 current_date-3,'pending',now()-interval '3 days') returning id
) select set_config('gc.pending',id::text,true) from x;
select set_config('request.jwt.claim.sub',current_setting('gc.admin'),true);
set local role authenticated;
do $t$ begin
 begin perform public.league_v21_admin_close_global_challenge(current_setting('gc.challenge')::uuid);
  raise exception 'Pending training did not block settlement';
 exception when check_violation then null;end;
end$t$;
reset role;
update public.training_submissions set status='approved' where id=current_setting('gc.pending')::uuid;
insert into public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
values(current_setting('gc.two')::uuid,(select id from public.training_types where is_active order by id limit 1),
 current_date-3,'approved',now()-interval '3 days');
set local role authenticated;
select public.league_v21_admin_close_global_challenge(current_setting('gc.challenge')::uuid);
select public.league_v21_admin_close_global_challenge(current_setting('gc.challenge')::uuid);
reset role;
do $t$ begin
 if (select count(*) from public.league_global_results_v21 where challenge_id=current_setting('gc.challenge')::uuid
  and rank_position=1 and completed)<>2 then raise exception 'Tied winners missing';end if;
 if (select count(*) from public.league_global_exp_ledger_v21 where challenge_id=current_setting('gc.challenge')::uuid
  and exp_amount=50)<>2 then raise exception 'One-time +50 EXP payouts missing';end if;
 if (select count(*) from public.point_transactions where description='Global challenge reward: '||
 current_setting('gc.challenge') and exp=50 and points=0)<>2 then raise exception 'Duplicate prize transaction';end if;
end$t$;
rollback;