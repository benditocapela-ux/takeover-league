-- ISOLATED TEST FIXTURE ONLY: production-equivalent actor contract.
-- Never apply this fixture to production.
create schema if not exists league_private;
revoke all on schema league_private from public,anon,authenticated;
create or replace function league_private.coach_v2_actor()
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare v_actor jsonb;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if not exists(select 1 from public.league_feature_flags where feature_key='coach_challenges' and is_enabled is true)
 then raise exception 'Coach Challenges not enabled' using errcode='42501';end if;
 select pg_catalog.jsonb_build_object('id',p.id,'role',p.role) into v_actor
 from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active is true;
 if v_actor is null or (v_actor->>'role') not in ('boxer','coach','admin')
 then raise exception 'Active league profile required' using errcode='42501';end if;
 return v_actor;
end
$function$;
revoke all on function league_private.coach_v2_actor() from public,anon,authenticated;
