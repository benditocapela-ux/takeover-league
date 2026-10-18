-- 2.1 auditable goal mutations. No awards or point transaction writes.
create schema if not exists league_v21_private;
revoke all on schema league_v21_private from public,anon,authenticated;
grant usage on schema league_v21_private to authenticated;
create or replace function league_v21_private.goal_upsert_core(
 p_goal_id uuid, p_boxer_id uuid, p_title text, p_metric text,
 p_target numeric, p_end_date date)
returns uuid language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype; target public.profiles%rowtype; result uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active;
 if not found or actor.role not in ('boxer','admin') then raise exception 'Active boxer or admin required' using errcode='42501';end if;
 select * into target from public.profiles p where p.id=p_boxer_id and p.is_active and p.role='boxer';
 if not found then raise exception 'Active boxer target required' using errcode='22023';end if;
 if actor.role='boxer' and actor.id<>target.id then raise exception 'Other boxer goal denied' using errcode='42501';end if;
 if p_title is null or length(trim(p_title)) not between 3 and 120
  or p_metric not in ('training_sessions','jogging_km','technique_minutes','custom')
  or p_target is null or p_target<=0 or p_target>1000000
  or p_end_date is null or p_end_date<current_date or p_end_date>current_date+interval '730 days'
 then raise exception 'Invalid goal fields' using errcode='22023';end if;
 if p_goal_id is null then
  insert into public.league_boxer_goals_v21
   (boxer_id,title,metric,target_value,ends_on,created_by)
  values(target.id,trim(p_title),p_metric,p_target,p_end_date,actor.id)
  returning id into result;
 else
  update public.league_boxer_goals_v21 g
  set title=trim(p_title),metric=p_metric,target_value=p_target,ends_on=p_end_date,updated_at=now()
  where g.id=p_goal_id and g.boxer_id=target.id and g.status='active'
  returning g.id into result;
  if result is null then raise exception 'Goal not found or archived' using errcode='22023';end if;
 end if;
 return result;
end$f$;
create or replace function league_v21_private.goal_progress_core(p_goal uuid,p_delta numeric,p_note text)
returns uuid language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype; goal public.league_boxer_goals_v21%rowtype; result uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active;
 if not found or actor.role not in ('boxer','admin') then raise exception 'Not authorized' using errcode='42501';end if;
 select * into goal from public.league_boxer_goals_v21 g where g.id=p_goal for update;
 if not found or goal.status<>'active' then raise exception 'Goal not active' using errcode='22023';end if;
 if actor.role='boxer' and actor.id<>goal.boxer_id then raise exception 'Other boxer goal denied' using errcode='42501';end if;
 if goal.metric<>'custom' and actor.role='boxer' then raise exception 'Automatic goals use confirmed submissions' using errcode='42501';end if;
 if p_delta is null or p_delta<=0 or p_delta>1000000 or length(coalesce(p_note,''))>500
 then raise exception 'Invalid progress amount' using errcode='22023';end if;
 insert into public.league_goal_progress_v21(goal_id,progress_delta,recorded_by,note)
 values(goal.id,p_delta,actor.id,nullif(trim(p_note),''))
 returning id into result;
 return result;
end$f$;
revoke all on function league_v21_private.goal_upsert_core(uuid,uuid,text,text,numeric,date) from public,anon,authenticated;
revoke all on function league_v21_private.goal_progress_core(uuid,numeric,text) from public,anon,authenticated;
grant execute on function league_v21_private.goal_upsert_core(uuid,uuid,text,text,numeric,date) to authenticated;
grant execute on function league_v21_private.goal_progress_core(uuid,numeric,text) to authenticated;
create or replace function public.league_v21_save_goal(
 p_goal_id uuid,p_boxer_id uuid,p_title text,p_metric text,p_target numeric,p_end_date date)
returns uuid language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.goal_upsert_core(p_goal_id,p_boxer_id,p_title,p_metric,p_target,p_end_date) $f$;
create or replace function public.league_v21_record_goal_progress(p_goal uuid,p_delta numeric,p_note text default null)
returns uuid language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.goal_progress_core(p_goal,p_delta,p_note) $f$;
revoke all on function public.league_v21_save_goal(uuid,uuid,text,text,numeric,date) from public,anon,authenticated;
revoke all on function public.league_v21_record_goal_progress(uuid,numeric,text) from public,anon,authenticated;
grant execute on function public.league_v21_save_goal(uuid,uuid,text,text,numeric,date) to authenticated;
grant execute on function public.league_v21_record_goal_progress(uuid,numeric,text) to authenticated;
