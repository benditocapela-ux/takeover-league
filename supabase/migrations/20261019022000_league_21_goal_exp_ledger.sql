-- Authoritative goal EXP with immutable admin-configured automatic goals.
-- One ledger per goal, no client-side rewards, no manual-metric payouts.
alter table public.league_boxer_goals_v21
 add column if not exists reward_exp integer not null default 0 check(reward_exp between 0 and 250);
create table if not exists public.league_goal_exp_ledger_v21(
 goal_id uuid primary key references public.league_boxer_goals_v21(id) on delete restrict,
 boxer_id uuid not null references public.profiles(id) on delete restrict,
 transaction_id uuid unique references public.point_transactions(id) on delete restrict,
 exp_amount integer not null check(exp_amount between 0 and 250),
 created_at timestamptz not null default now()
);
alter table public.league_goal_exp_ledger_v21 enable row level security;
revoke all on public.league_goal_exp_ledger_v21 from public,anon,authenticated;

create or replace function league_v21_private.set_goal_reward_core(p_goal uuid,p_exp integer)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype;g public.league_boxer_goals_v21%rowtype;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Admin only' using errcode='42501';end if;
 if p_exp is null or p_exp not between 0 and 250 then raise exception 'Invalid EXP' using errcode='22023';end if;
 select * into g from public.league_boxer_goals_v21 where id=p_goal for update;
 if not found or g.status<>'active' or g.metric='custom' then raise exception 'Only active automatic goals may earn EXP' using errcode='22023';end if;
 if exists(select 1 from public.league_goal_exp_ledger_v21 where goal_id=g.id) then raise exception 'Reward already reconciled' using errcode='23505';end if;
 update public.league_boxer_goals_v21 set reward_exp=p_exp,updated_at=now() where id=g.id;
 return pg_catalog.jsonb_build_object('reward_exp',p_exp);
end$f$;
revoke all on function league_v21_private.set_goal_reward_core(uuid,integer) from public,anon,authenticated;
grant execute on function league_v21_private.set_goal_reward_core(uuid,integer) to authenticated;
create or replace function public.league_v21_admin_set_goal_reward(p_goal uuid,p_exp integer)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.set_goal_reward_core(p_goal,p_exp) $f$;
revoke all on function public.league_v21_admin_set_goal_reward(uuid,integer) from public,anon,authenticated;
grant execute on function public.league_v21_admin_set_goal_reward(uuid,integer) to authenticated;

create or replace function league_v21_private.goal_immutable_reward_fields()
returns trigger language plpgsql security definer set search_path='' as $f$
begin
 if old.reward_exp>0 and (
  old.boxer_id is distinct from new.boxer_id or
  old.metric is distinct from new.metric or
  old.target_value is distinct from new.target_value or
  old.starts_on is distinct from new.starts_on or
  old.ends_on is distinct from new.ends_on or
  old.created_by is distinct from new.created_by
 ) then raise exception 'Rewarded goal parameters are immutable' using errcode='42501';end if;
 return new;
end$f$;
revoke all on function league_v21_private.goal_immutable_reward_fields() from public,anon,authenticated;
drop trigger if exists league_v21_immutable_reward_fields on public.league_boxer_goals_v21;
create trigger league_v21_immutable_reward_fields
before update on public.league_boxer_goals_v21
for each row execute function league_v21_private.goal_immutable_reward_fields();

create or replace function league_v21_private.complete_and_reward_goal_core(p_goal uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $f$
declare actor public.profiles%rowtype;g public.league_boxer_goals_v21%rowtype;
 progress numeric:=0;changed boolean:=false;existing public.league_goal_exp_ledger_v21%rowtype;tx uuid;awarded integer:=0;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role in ('boxer','admin');
 if not found then raise exception 'Active boxer/admin required' using errcode='42501';end if;
 select * into g from public.league_boxer_goals_v21 where id=p_goal for update;
 if not found then raise exception 'Goal not found' using errcode='22023';end if;
 if actor.role='boxer' and actor.id<>g.boxer_id then raise exception 'Other boxer goal forbidden' using errcode='42501';end if;
 if g.metric='custom' then
  select coalesce(sum(progress_delta),0) into progress from public.league_goal_progress_v21 where goal_id=g.id;
 else
  select case g.metric
    when 'training_sessions' then count(*)::numeric
    when 'jogging_km' then coalesce(sum(s.jogging_km),0)
    when 'technique_minutes' then coalesce(sum(s.technique_minutes),0)
    else 0 end
  into progress from public.training_submissions s
  where s.boxer_id=g.boxer_id and s.status='approved'
    and s.training_date between g.starts_on and g.ends_on;
 end if;
 if g.status='active' and progress>=g.target_value then
  update public.league_boxer_goals_v21 set status='completed',updated_at=now() where id=g.id;
  changed=true;
 end if;
 if (changed or g.status='completed') and g.reward_exp>0 then
  if g.metric='custom' then raise exception 'Manual goal cannot pay EXP' using errcode='42501';end if;
  select * into existing from public.league_goal_exp_ledger_v21 where goal_id=g.id for update;
  if found then
   if existing.boxer_id<>g.boxer_id or existing.exp_amount<>g.reward_exp
     or existing.transaction_id is null
     or not exists(select 1 from public.point_transactions t where t.id=existing.transaction_id
      and t.boxer_id=g.boxer_id and t.category='challenge_exp'
      and t.exp=g.reward_exp and t.points=0
      and t.description='Personal goal reward: '||g.id::text)
   then raise exception 'Goal EXP ledger integrity mismatch' using errcode='23514';end if;
  else
   if exists(select 1 from public.point_transactions t
    where t.boxer_id=g.boxer_id and t.category='challenge_exp'
      and t.description='Personal goal reward: '||g.id::text)
   then raise exception 'Orphaned goal payout must be investigated' using errcode='23514';end if;
   insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
   values(g.boxer_id,null,0,g.reward_exp,'challenge_exp','Personal goal reward: '||g.id::text,current_date,actor.id)
   returning id into tx;
   insert into public.league_goal_exp_ledger_v21(goal_id,boxer_id,transaction_id,exp_amount)
   values(g.id,g.boxer_id,tx,g.reward_exp);
  end if;
  awarded=g.reward_exp;
 end if;
 return pg_catalog.jsonb_build_object('status',case when changed then 'completed' else g.status end,
 'progress',progress,'target',g.target_value,'changed',changed,'exp_awarded',awarded);
end$f$;
revoke all on function league_v21_private.complete_and_reward_goal_core(uuid) from public,anon,authenticated;
grant execute on function league_v21_private.complete_and_reward_goal_core(uuid) to authenticated;
create or replace function public.league_v21_complete_goal(p_goal uuid)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.complete_and_reward_goal_core(p_goal) $f$;
revoke all on function public.league_v21_complete_goal(uuid) from public,anon,authenticated;
grant execute on function public.league_v21_complete_goal(uuid) to authenticated;
