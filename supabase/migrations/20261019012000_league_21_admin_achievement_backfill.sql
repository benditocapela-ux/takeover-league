-- Achievement backfill v2.1: bounded, admin-only and reuses the existing
-- transaction-aware achievement reconciler; no independent EXP awards.
create or replace function league_v21_private.reconcile_achievements_core(p_limit integer default 10,p_after uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare v_actor public.profiles%rowtype;row record;v_count integer:=0;v_last uuid:=p_after;
begin
 select * into v_actor from public.profiles p where p.auth_user_id=(select auth.uid())
 and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin may reconcile achievements' using errcode='42501';end if;
 if p_limit is null or p_limit not between 1 and 25 then raise exception 'Limit must be 1-25' using errcode='22023';end if;
 if to_regprocedure('public.recalculate_boxer_achievements_v2(uuid)') is null
 then raise exception 'Existing achievement reconciler unavailable' using errcode='0A000';end if;
 for row in select p.id from public.profiles p
  where p.role='boxer' and p.is_active and (p_after is null or p.id>p_after)
  order by p.id limit p_limit loop
   perform public.recalculate_boxer_achievements_v2(row.id);
   v_count:=v_count+1;v_last:=row.id;
 end loop;
 return pg_catalog.jsonb_build_object('processed',v_count,'last_boxer_id',v_last,'has_more',
  exists(select 1 from public.profiles p where p.role='boxer' and p.is_active and (v_last is null or p.id>v_last)));
end$f$;
revoke all on function league_v21_private.reconcile_achievements_core(integer,uuid) from public,anon,authenticated;
grant execute on function league_v21_private.reconcile_achievements_core(integer,uuid) to authenticated;
create or replace function public.league_v21_reconcile_achievements(p_limit integer default 10,p_after uuid default null)
returns jsonb language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.reconcile_achievements_core(p_limit,p_after) $f$;
revoke all on function public.league_v21_reconcile_achievements(integer,uuid) from public,anon,authenticated;
grant execute on function public.league_v21_reconcile_achievements(integer,uuid) to authenticated;
