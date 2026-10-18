-- STAGING ONLY. All fixtures and EXP changes are rolled back.
BEGIN;
select set_config('gc.admin_auth',(select auth_user_id::text from public.profiles
 where role='admin' and is_active and auth_user_id is not null limit 1),true);
select set_config('gc.admin',(select id::text from public.profiles
 where role='admin' and is_active and auth_user_id is not null limit 1),true);
select set_config('gc.one',(select id::text from public.profiles
 where role='boxer' and is_active order by id limit 1),true);
select set_config('gc.two',(select id::text from public.profiles
 where role='boxer' and is_active order by id desc limit 1),true);
do $a$ begin if current_setting('gc.one')=current_setting('gc.two') then
 raise exception 'Two boxer fixture profiles are required';end if;end$a$;
with added as (
 insert into public.league_boxer_goals_v21(boxer_id,title,metric,target_value,
  starts_on,ends_on,status,created_by,reward_exp)
 values(current_setting('gc.one')::uuid,'TEST transfer previous goal','training_sessions',1,
  current_date,current_date,'active',current_setting('gc.admin')::uuid,75)
 returning id
) select set_config('gc.goal_one',id::text,true) from added;
with added as (
 insert into public.league_boxer_goals_v21(boxer_id,title,metric,target_value,
  starts_on,ends_on,status,created_by,reward_exp)
 values(current_setting('gc.two')::uuid,'TEST transfer new owner goal','training_sessions',1,
  current_date,current_date,'active',current_setting('gc.admin')::uuid,50)
 returning id
) select set_config('gc.goal_two',id::text,true) from added;
with added as (
 insert into public.training_submissions(boxer_id,training_type_id,training_date,notes,status)
 values(current_setting('gc.one')::uuid,(select id from public.training_types
 where is_active order by id limit 1),current_date,'TEST transfer approved fixture','approved')
 returning id
) select set_config('gc.training',id::text,true) from added;
select set_config('request.jwt.claim.sub',current_setting('gc.admin_auth'),true);
SET LOCAL ROLE authenticated;
select public.league_v21_complete_goal(current_setting('gc.goal_one')::uuid);
RESET ROLE;
do $a$ begin if (select status from public.league_boxer_goals_v21
 where id=current_setting('gc.goal_one')::uuid)<>'completed'
 or (select exp from public.point_transactions t
 join public.league_goal_exp_ledger_v21 l on l.transaction_id=t.id
 where l.goal_id=current_setting('gc.goal_one')::uuid)<>75
 then raise exception 'Initial goal reward missing';end if;end$a$;
-- The admin transfers a still-approved session to a different boxer.
update public.training_submissions set boxer_id=current_setting('gc.two')::uuid
 where id=current_setting('gc.training')::uuid;
do $a$ begin
 if (select status from public.league_boxer_goals_v21
 where id=current_setting('gc.goal_one')::uuid)<>'active'
 or (select exp from public.point_transactions t
 join public.league_goal_exp_ledger_v21 l on l.transaction_id=t.id
 where l.goal_id=current_setting('gc.goal_one')::uuid)<>0 then
  raise exception 'Old boxer EXP not revoked after transfer';end if;
 if (select status from public.league_boxer_goals_v21
 where id=current_setting('gc.goal_two')::uuid)<>'completed'
 or (select exp from public.point_transactions t
 join public.league_goal_exp_ledger_v21 l on l.transaction_id=t.id
 where l.goal_id=current_setting('gc.goal_two')::uuid)<>50 then
  raise exception 'New boxer EXP missing after transfer';end if;
 perform set_config('gc.reward_tx',(select transaction_id::text from
  public.league_goal_exp_ledger_v21 where goal_id=current_setting('gc.goal_two')::uuid),true);
end$a$;
-- The reviewer changes only the training date, status stays approved.
update public.training_submissions set training_date=current_date-1
 where id=current_setting('gc.training')::uuid;
do $a$ begin
 if (select status from public.league_boxer_goals_v21
 where id=current_setting('gc.goal_two')::uuid)<>'active'
 or (select exp from public.point_transactions where id=current_setting('gc.reward_tx')::uuid)<>0
 then raise exception 'Date correction did not revoke goal EXP';end if;
end$a$;
update public.training_submissions set training_date=current_date
 where id=current_setting('gc.training')::uuid;
do $a$ begin
 if (select status from public.league_boxer_goals_v21
 where id=current_setting('gc.goal_two')::uuid)<>'completed'
 or (select exp from public.point_transactions where id=current_setting('gc.reward_tx')::uuid)<>50
 or (select count(*) from public.league_goal_exp_ledger_v21
  where goal_id=current_setting('gc.goal_two')::uuid)<>1
 then raise exception 'Date correction did not restore reward idempotently';end if;
end$a$;
ROLLBACK;