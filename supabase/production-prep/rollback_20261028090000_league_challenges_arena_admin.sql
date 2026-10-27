-- Rollback for 20261028090000_league_challenges_arena_admin.sql.
-- Removes the new draft/publish/delete and arena-cancel RPCs and restores arena_create_core
-- (21.10. state). Rows created meanwhile (published challenges, cancelled arenas, notifications) stay.
BEGIN;
DROP FUNCTION IF EXISTS public.league_v21_admin_update_global_draft(uuid,text,text,text,numeric,timestamptz,timestamptz);
DROP FUNCTION IF EXISTS public.league_v21_admin_publish_global_challenge(uuid);
DROP FUNCTION IF EXISTS public.league_v21_admin_delete_global_draft(uuid);
DROP FUNCTION IF EXISTS public.league_v21_arena_cancel(uuid);
DROP FUNCTION IF EXISTS league_v21_private.global_draft_update_core(uuid,text,text,text,numeric,timestamptz,timestamptz);
DROP FUNCTION IF EXISTS league_v21_private.global_publish_core(uuid);
DROP FUNCTION IF EXISTS league_v21_private.global_delete_draft_core(uuid);
DROP FUNCTION IF EXISTS league_v21_private.arena_cancel_core(uuid);

CREATE OR REPLACE FUNCTION league_v21_private.arena_create_core(p_title text, p_duration integer, p_boxers uuid[])
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare actor public.profiles%rowtype;result uuid;num integer;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Only active admin may invite a multiplayer arena' using errcode='42501';end if;
 if p_title is null or length(trim(p_title)) not between 3 and 120 or p_duration not in (7,14)
  or p_boxers is null or pg_catalog.array_length(p_boxers,1) not between 3 and 8
 then raise exception 'Arena requires 3-8 boxers' using errcode='22023';end if;
 select count(distinct id) into num from pg_catalog.unnest(p_boxers) id;
 if num<>pg_catalog.array_length(p_boxers,1) then raise exception 'Duplicate boxer invitation' using errcode='22023';end if;
 if (select count(*) from public.profiles p where p.id=any(p_boxers) and p.role='boxer' and p.is_active)<>num
 then raise exception 'All invitees must be active boxers' using errcode='22023';end if;
 insert into public.league_arena_duels_v21(title,duration_days,created_by)
 values(trim(p_title),p_duration,actor.id) returning id into result;
 insert into public.league_arena_members_v21(arena_id,boxer_id)
 select result,id from pg_catalog.unnest(p_boxers) id;
 return result;
end$function$;
NOTIFY pgrst, 'reload schema';
COMMIT;
