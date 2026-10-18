-- Report actual currently active EXP, not the configured maximum after a reward was revoked.
create or replace function league_v21_private.complete_and_reward_goal_core(p_goal uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $f$
declare actor public.profiles%rowtype;g public.league_boxer_goals_v21%rowtype;
 progress numeric:=0;changed boolean:=false;reopened boolean:=false;existing public.league_goal_exp_ledger_v21%rowtype;tx uuid;awarded integer:=0;expected_exp integer;
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
 if g.status='completed' and progress<g.target_value then
  update public.league_boxer_goals_v21 set status='active',updated_at=now() where id=g.id;
  reopened=true;
 end if;
 if g.reward_exp>0 then
  if g.metric='custom' then raise exception 'Manual goal cannot pay EXP' using errcode='42501';end if;
  select * into existing from public.league_goal_exp_ledger_v21 where goal_id=g.id for update;
  if found then
   if existing.boxer_id<>g.boxer_id or existing.exp_amount<>g.reward_exp
     or existing.transaction_id is null
     or not exists(select 1 from public.point_transactions t where t.id=existing.transaction_id
      and t.boxer_id=g.boxer_id and t.category='challenge_exp'
      and t.exp in (0,g.reward_exp) and t.points=0
      and t.description='Personal goal reward: '||g.id::text)
   then raise exception 'Goal EXP ledger integrity mismatch' using errcode='23514';end if;
   expected_exp:=case when progress>=g.target_value and (changed or g.status='completed') then g.reward_exp else 0 end;
   update public.point_transactions t set exp=expected_exp
    where t.id=existing.transaction_id and t.exp is distinct from expected_exp;
   awarded=expected_exp;
  elsif (changed or g.status='completed') and progress>=g.target_value then
   if exists(select 1 from public.point_transactions t
    where t.boxer_id=g.boxer_id and t.category='challenge_exp'
      and t.description='Personal goal reward: '||g.id::text)
   then raise exception 'Orphaned goal payout must be investigated' using errcode='23514';end if;
   insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
   values(g.boxer_id,null,0,g.reward_exp,'challenge_exp','Personal goal reward: '||g.id::text,current_date,actor.id)
   returning id into tx;
   insert into public.league_goal_exp_ledger_v21(goal_id,boxer_id,transaction_id,exp_amount)
   values(g.id,g.boxer_id,tx,g.reward_exp);
   awarded=g.reward_exp;
  end if;
 end if;
 return pg_catalog.jsonb_build_object('status',
   case when reopened then 'active' when changed then 'completed' else g.status end,
 'progress',progress,'target',g.target_value,'changed',changed,'reopened',reopened,
 'exp_awarded',awarded);
end$f$;
