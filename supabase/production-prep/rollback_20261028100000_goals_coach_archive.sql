-- Rollback for 20261028100000_goals_coach_archive.sql.
-- Restores the 27.10.2026 goal functions and read policy. Goals archived meanwhile stay archived,
-- progress rows, EXP ledger and notifications are kept.
BEGIN;
DROP FUNCTION IF EXISTS public.league_v21_archive_goal(uuid);
DROP FUNCTION IF EXISTS league_v21_private.goal_archive_core(uuid);

CREATE OR REPLACE FUNCTION league_v21_private.goal_upsert_core(p_goal_id uuid, p_boxer_id uuid, p_title text, p_metric text, p_target numeric, p_end_date date)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
declare actor public.profiles%rowtype; target public.profiles%rowtype; result uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active;
 if not found or actor.role not in ('boxer','admin') then raise exception 'Active boxer or admin required' using errcode='42501';end if;
 select * into target from public.profiles p where p.id=p_boxer_id and p.is_active and p.role='boxer';
 if not found then raise exception 'Active boxer target required' using errcode='22023';end if;
 if actor.role='boxer' and actor.id<>target.id then raise exception 'Other boxer goal denied' using errcode='42501';end if;
 if p_title is null or length(trim(p_title)) not between 3 and 120 or p_metric not in ('training_sessions','jogging_km','technique_minutes','custom')
  or p_target is null or p_target<=0 or p_target>1000000 or p_end_date is null or p_end_date<current_date or p_end_date>current_date+interval '730 days'
 then raise exception 'Invalid goal fields' using errcode='22023';end if;
 if p_goal_id is null then
  insert into public.league_boxer_goals_v21 (boxer_id,title,metric,target_value,ends_on,created_by) values(target.id,trim(p_title),p_metric,p_target,p_end_date,actor.id) returning id into result;
 else
  update public.league_boxer_goals_v21 g set title=trim(p_title),metric=p_metric,target_value=p_target,ends_on=p_end_date,updated_at=now()
  where g.id=p_goal_id and g.boxer_id=target.id and g.status='active' returning g.id into result;
  if result is null then raise exception 'Goal not found or archived' using errcode='22023';end if;
 end if;
 return result;
end$function$;

CREATE OR REPLACE FUNCTION league_v21_private.goal_progress_core(p_goal uuid, p_delta numeric, p_note text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
declare actor public.profiles%rowtype; goal public.league_boxer_goals_v21%rowtype; result uuid;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active;
 if not found or actor.role not in ('boxer','admin') then raise exception 'Not authorized' using errcode='42501';end if;
 select * into goal from public.league_boxer_goals_v21 g where g.id=p_goal for update;
 if not found or goal.status<>'active' then raise exception 'Goal not active' using errcode='22023';end if;
 if actor.role='boxer' and actor.id<>goal.boxer_id then raise exception 'Other boxer goal denied' using errcode='42501';end if;
 if goal.metric<>'custom' and actor.role='boxer' then raise exception 'Automatic goals use confirmed submissions' using errcode='42501';end if;
 if p_delta is null or p_delta<=0 or p_delta>1000000 or length(coalesce(p_note,''))>500 then raise exception 'Invalid progress amount' using errcode='22023';end if;
 insert into public.league_goal_progress_v21(goal_id,progress_delta,recorded_by,note) values(goal.id,p_delta,actor.id,nullif(trim(p_note),'')) returning id into result;
 return result;
end$function$;

CREATE OR REPLACE FUNCTION league_v21_private.complete_goal_core(p_goal uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
declare actor public.profiles%rowtype;g public.league_boxer_goals_v21%rowtype;progress numeric:=0;changed boolean:=false;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role in ('boxer','admin');
 if not found then raise exception 'Active boxer/admin required' using errcode='42501';end if;
 select * into g from public.league_boxer_goals_v21 where id=p_goal for update;
 if not found then raise exception 'Goal not found' using errcode='22023';end if;
 if actor.role='boxer' and actor.id<>g.boxer_id then raise exception 'Other boxer goal forbidden' using errcode='42501';end if;
 if g.metric='custom' then select coalesce(sum(progress_delta),0) into progress from public.league_goal_progress_v21 where goal_id=g.id;
 else select case g.metric when 'training_sessions' then count(*)::numeric when 'jogging_km' then coalesce(sum(s.jogging_km),0) when 'technique_minutes' then coalesce(sum(s.technique_minutes),0) else 0 end into progress
  from public.training_submissions s where s.boxer_id=g.boxer_id and s.status='approved' and s.training_date between g.starts_on and g.ends_on; end if;
 if g.status='active' and progress>=g.target_value then update public.league_boxer_goals_v21 set status='completed',updated_at=now() where id=g.id; changed=true; end if;
 return pg_catalog.jsonb_build_object('status',case when changed then 'completed' else g.status end,'progress',progress,'target',g.target_value,'changed',changed,'exp_awarded',0);
end$function$;

CREATE OR REPLACE FUNCTION league_v21_private.complete_and_reward_goal_core(p_goal uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
declare actor public.profiles%rowtype;g public.league_boxer_goals_v21%rowtype;
 progress numeric:=0;changed boolean:=false;reopened boolean:=false;existing public.league_goal_exp_ledger_v21%rowtype;tx uuid;awarded integer:=0;expected_exp integer;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role in ('boxer','admin');
 if not found then raise exception 'Active boxer/admin required' using errcode='42501';end if;
 select * into g from public.league_boxer_goals_v21 where id=p_goal for update;
 if not found then raise exception 'Goal not found' using errcode='22023';end if;
 if actor.role='boxer' and actor.id<>g.boxer_id then raise exception 'Other boxer goal forbidden' using errcode='42501';end if;
 if g.metric='custom' then select coalesce(sum(progress_delta),0) into progress from public.league_goal_progress_v21 where goal_id=g.id;
 else select case g.metric when 'training_sessions' then count(*)::numeric when 'jogging_km' then coalesce(sum(s.jogging_km),0) when 'technique_minutes' then coalesce(sum(s.technique_minutes),0) else 0 end into progress
  from public.training_submissions s where s.boxer_id=g.boxer_id and s.status='approved' and s.training_date between g.starts_on and g.ends_on; end if;
 if g.status='active' and progress>=g.target_value then update public.league_boxer_goals_v21 set status='completed',updated_at=now() where id=g.id; changed=true; end if;
 if g.status='completed' and progress<g.target_value then update public.league_boxer_goals_v21 set status='active',updated_at=now() where id=g.id; reopened=true; end if;
 if g.reward_exp>0 then
  if g.metric='custom' then raise exception 'Manual goal cannot pay EXP' using errcode='42501';end if;
  select * into existing from public.league_goal_exp_ledger_v21 where goal_id=g.id for update;
  if found then
   if existing.boxer_id<>g.boxer_id or existing.exp_amount<>g.reward_exp or existing.transaction_id is null
    or not exists(select 1 from public.point_transactions t where t.id=existing.transaction_id and t.boxer_id=g.boxer_id and t.category='challenge_exp' and t.exp in (0,g.reward_exp) and t.points=0 and t.description='Personal goal reward: '||g.id::text)
   then raise exception 'Goal EXP ledger integrity mismatch' using errcode='23514';end if;
   expected_exp:=case when progress>=g.target_value and (changed or g.status='completed') then g.reward_exp else 0 end;
   update public.point_transactions t set exp=expected_exp where t.id=existing.transaction_id and t.exp is distinct from expected_exp; awarded=expected_exp;
  elsif (changed or g.status='completed') and progress>=g.target_value then
   if exists(select 1 from public.point_transactions t where t.boxer_id=g.boxer_id and t.category='challenge_exp' and t.description='Personal goal reward: '||g.id::text)
   then raise exception 'Orphaned goal payout must be investigated' using errcode='23514';end if;
   insert into public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
   values(g.boxer_id,null,0,g.reward_exp,'challenge_exp','Personal goal reward: '||g.id::text,current_date,actor.id) returning id into tx;
   insert into public.league_goal_exp_ledger_v21(goal_id,boxer_id,transaction_id,exp_amount) values(g.id,g.boxer_id,tx,g.reward_exp); awarded=g.reward_exp;
  end if;
 end if;
 return pg_catalog.jsonb_build_object('status', case when reopened then 'active' when changed then 'completed' else g.status end,'progress',progress,'target',g.target_value,'changed',changed,'reopened',reopened,'exp_awarded',awarded);
end$function$;

CREATE OR REPLACE FUNCTION league_v21_private.goal_after_training_review()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
declare actor public.profiles%rowtype; g record;
begin
 if (OLD.status IS DISTINCT FROM NEW.status or OLD.boxer_id IS DISTINCT FROM NEW.boxer_id or OLD.training_date IS DISTINCT FROM NEW.training_date
     or OLD.jogging_km IS DISTINCT FROM NEW.jogging_km or OLD.technique_minutes IS DISTINCT FROM NEW.technique_minutes) is false
    or (OLD.status<>'approved' and NEW.status<>'approved') then return NEW;end if;
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then return NEW; end if;
 for g in select x.id from public.league_boxer_goals_v21 x where x.metric<>'custom' and x.status in ('active','completed') and (
    (OLD.status='approved' and x.boxer_id=OLD.boxer_id and OLD.training_date between x.starts_on and x.ends_on) or
    (NEW.status='approved' and x.boxer_id=NEW.boxer_id and NEW.training_date between x.starts_on and x.ends_on)) order by x.id loop
  perform league_v21_private.complete_and_reward_goal_core(g.id);
 end loop;
 return NEW;
end$function$;

DROP FUNCTION IF EXISTS league_v21_private.notify_goal_completed(uuid,integer);

DROP POLICY IF EXISTS "Owner or admin reads goals" ON public.league_boxer_goals_v21;
CREATE POLICY "Owner or admin reads goals" ON public.league_boxer_goals_v21 FOR SELECT TO authenticated
USING (
 EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=league_boxer_goals_v21.boxer_id AND p.auth_user_id=(SELECT auth.uid()) AND p.is_active)
 OR EXISTS (SELECT 1 FROM public.profiles admin WHERE admin.auth_user_id=(SELECT auth.uid()) AND admin.is_active AND admin.role='admin')
);
NOTIFY pgrst, 'reload schema';
COMMIT;
