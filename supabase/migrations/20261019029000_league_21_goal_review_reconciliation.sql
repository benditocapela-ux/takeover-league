-- Goal reward reconciliation after a training status changes.
-- Trigger is limited to an authenticated active admin reviewer; legacy service imports
-- can be reconciled with the bounded admin RPC without blocking imports.
create or replace function league_v21_private.goal_after_training_review()
returns trigger language plpgsql security definer set search_path='' as $f$
declare actor public.profiles%rowtype;g record;
begin
 if OLD.status IS NOT DISTINCT FROM NEW.status
    or (OLD.status<>'approved' and NEW.status<>'approved') then return NEW;end if;
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid())
   and p.is_active and p.role='admin';
 if not found then return NEW;end if;
 for g in select id from public.league_boxer_goals_v21
  where boxer_id=NEW.boxer_id and metric<>'custom'
    and status in ('active','completed')
    and NEW.training_date between starts_on and ends_on
  order by id loop
  perform league_v21_private.complete_and_reward_goal_core(g.id);
 end loop;
 return NEW;
end$f$;
revoke all on function league_v21_private.goal_after_training_review() from public,anon,authenticated;
drop trigger if exists league_v21_goal_after_training_review on public.training_submissions;
create trigger league_v21_goal_after_training_review
after update of status on public.training_submissions
for each row when (OLD.status IS DISTINCT FROM NEW.status)
execute function league_v21_private.goal_after_training_review();

-- Admin reconciles historic corrections/imports in 1–25-goal batches.
create or replace function league_v21_private.goal_batch_reconcile_core(p_limit integer default 10,p_after uuid default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $f$
declare actor public.profiles%rowtype;g record;processed integer:=0;last_id uuid:=p_after;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid())
  and p.is_active and p.role='admin';
 if not found then raise exception 'Admin required' using errcode='42501';end if;
 if p_limit is null or p_limit not between 1 and 25 then raise exception 'Limit 1–25 required' using errcode='22023';end if;
 for g in select id from public.league_boxer_goals_v21
  where metric<>'custom' and status in ('active','completed')
    and (p_after is null or id>p_after)
  order by id limit p_limit loop
   perform league_v21_private.complete_and_reward_goal_core(g.id);
   processed:=processed+1;last_id:=g.id;
 end loop;
 return pg_catalog.jsonb_build_object('processed',processed,'last_goal_id',last_id,
  'has_more',exists(select 1 from public.league_boxer_goals_v21
    where metric<>'custom' and status in ('active','completed')
    and (last_id is null or id>last_id)));
end$f$;
revoke all on function league_v21_private.goal_batch_reconcile_core(integer,uuid) from public,anon,authenticated;
grant execute on function league_v21_private.goal_batch_reconcile_core(integer,uuid) to authenticated;
create or replace function public.league_v21_admin_reconcile_goals(p_limit integer default 10,p_after uuid default null)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.goal_batch_reconcile_core(p_limit,p_after) $f$;
revoke all on function public.league_v21_admin_reconcile_goals(integer,uuid) from public,anon,authenticated;
grant execute on function public.league_v21_admin_reconcile_goals(integer,uuid) to authenticated;
