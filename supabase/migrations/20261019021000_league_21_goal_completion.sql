-- Goal completion uses server-side approved training data; ZERO automatic EXP.
create or replace function league_v21_private.complete_goal_core(p_goal uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $f$
declare actor public.profiles%rowtype;g public.league_boxer_goals_v21%rowtype;progress numeric:=0;changed boolean:=false;
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
 return pg_catalog.jsonb_build_object('status',case when changed then 'completed' else g.status end,
 'progress',progress,'target',g.target_value,'changed',changed,'exp_awarded',0);
end$f$;
revoke all on function league_v21_private.complete_goal_core(uuid) from public,anon,authenticated;
grant execute on function league_v21_private.complete_goal_core(uuid) to authenticated;
create or replace function public.league_v21_complete_goal(p_goal uuid)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.complete_goal_core(p_goal) $f$;
revoke all on function public.league_v21_complete_goal(uuid) from public,anon,authenticated;
grant execute on function public.league_v21_complete_goal(uuid) to authenticated;
