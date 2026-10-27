-- Liga-Challenges und Mehrkampf-Arena: fehlende Verwaltung vervollständigen (27.10.2026).
--  * Liga-Challenge-Entwürfe: bearbeiten, veröffentlichen, unbenutzt löschen (vorher war ein
--    Entwurf eine Sackgasse: weder veröffentlichbar noch löschbar).
--  * Arena: Admin kann eine Einladung oder eine laufende, noch nicht gewertete Arena absagen
--    (Status 'cancelled' war im Schema vorgesehen, aber ohne RPC). Ergebnisse/EXP werden nie gelöscht.
--  * Arena-Einladungen nur noch für öffentliche Boxer (aktiv, freigegeben, nicht archiviert),
--    weil die Live-Wertung nicht öffentliche Teilnehmer ohnehin sperrt.
--  * Mitteilungen: Arena-Einladung und Arena-Absage an die Teilnehmer.
-- Bestehende RPC-Signaturen bleiben unverändert. Keine Punkte, EXP, Trainings oder Ergebnisse werden verändert.
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;

-- ---------------------------------------------------------------------------
-- Liga-Challenge-Entwurf bearbeiten
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.global_draft_update_core(
 p_challenge uuid, p_title text, p_description text, p_metric text, p_target numeric,
 p_starts timestamp with time zone, p_ends timestamp with time zone)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
declare actor public.profiles%rowtype; c public.league_global_challenges_v21%rowtype;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Nur aktive Admins dürfen Liga-Challenges bearbeiten' using errcode='42501';end if;
 select * into c from public.league_global_challenges_v21 x where x.id=p_challenge for update;
 if not found then raise exception 'Liga-Challenge nicht gefunden' using errcode='P0002';end if;
 if c.status<>'draft' then raise exception 'Nur Entwürfe können vollständig bearbeitet werden' using errcode='22023';end if;
 if p_title is null or length(trim(p_title)) not between 3 and 120
    or length(coalesce(p_description,''))>1000
    or p_metric is null or p_metric not in ('training_sessions','jogging_km','technique_minutes')
    or p_target is null or p_target<=0 or p_target>1000000
    or p_starts is null or p_ends is null or p_ends<=p_starts or p_ends>p_starts+interval '90 days'
 then raise exception 'Ungültige Angaben (Titel 3–120 Zeichen, Ziel > 0, Zeitraum höchstens 90 Tage)' using errcode='22023';end if;
 update public.league_global_challenges_v21
 set title=trim(p_title),description=coalesce(trim(p_description),''),metric=p_metric,
     target_value=p_target,starts_at=p_starts,ends_at=p_ends
 where id=c.id;
 return pg_catalog.jsonb_build_object('id',c.id,'status','draft');
end$fn$;

-- ---------------------------------------------------------------------------
-- Liga-Challenge-Entwurf veröffentlichen
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.global_publish_core(p_challenge uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
declare actor public.profiles%rowtype; c public.league_global_challenges_v21%rowtype;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Nur aktive Admins dürfen Liga-Challenges veröffentlichen' using errcode='42501';end if;
 select * into c from public.league_global_challenges_v21 x where x.id=p_challenge for update;
 if not found then raise exception 'Liga-Challenge nicht gefunden' using errcode='P0002';end if;
 if c.status='active' then return pg_catalog.jsonb_build_object('id',c.id,'status','active','unchanged',true);end if;
 if c.status<>'draft' then raise exception 'Nur Entwürfe können veröffentlicht werden' using errcode='22023';end if;
 if c.ends_at<=now() then
  raise exception 'Der Zeitraum ist bereits vorbei. Bitte zuerst Beginn und Ende anpassen.' using errcode='22023';end if;
 update public.league_global_challenges_v21 set status='active' where id=c.id;
 return pg_catalog.jsonb_build_object('id',c.id,'status','active');
end$fn$;

-- ---------------------------------------------------------------------------
-- Unbenutzten Liga-Challenge-Entwurf löschen
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.global_delete_draft_core(p_challenge uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
declare actor public.profiles%rowtype; c public.league_global_challenges_v21%rowtype;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Nur aktive Admins dürfen Entwürfe löschen' using errcode='42501';end if;
 select * into c from public.league_global_challenges_v21 x where x.id=p_challenge for update;
 if not found then raise exception 'Liga-Challenge nicht gefunden' using errcode='P0002';end if;
 if c.status<>'draft' then
  raise exception 'Nur Entwürfe können gelöscht werden; veröffentlichte Challenges bleiben als Historie erhalten' using errcode='22023';end if;
 if exists(select 1 from public.league_global_entries_v21 e where e.challenge_id=c.id)
    or exists(select 1 from public.league_global_results_v21 r where r.challenge_id=c.id)
    or exists(select 1 from public.league_global_exp_ledger_v21 l where l.challenge_id=c.id)
    or exists(select 1 from public.point_transactions t where t.category='challenge_exp'
              and t.description='Global challenge reward: '||c.id::text)
 then raise exception 'Entwurf hat bereits Verknüpfungen oder Historie und kann nicht gelöscht werden' using errcode='23503';end if;
 delete from public.league_global_challenges_v21 where id=c.id;
 return 'deleted';
end$fn$;

-- ---------------------------------------------------------------------------
-- Arena: nur öffentliche Boxer einladen, Einladung als Mitteilung
-- ---------------------------------------------------------------------------
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
 -- Live-Wertung und Ranglisten zeigen Namen: nur öffentliche, aktive Boxer einladen.
 if (select count(*) from public.profiles p where p.id=any(p_boxers) and p.role='boxer' and p.is_active
       and p.is_listed and p.archived_at is null)<>num
 then raise exception 'All invitees must be active boxers' using errcode='22023';end if;
 insert into public.league_arena_duels_v21(title,duration_days,created_by)
 values(trim(p_title),p_duration,actor.id) returning id into result;
 insert into public.league_arena_members_v21(arena_id,boxer_id)
 select result,id from pg_catalog.unnest(p_boxers) id;
 if league_v21_private.notifications_enabled() then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
  select id,'boxer_duel',pg_catalog.left('Einladung zur Arena «'||trim(p_title)||'»',160),
   'Du wurdest zu einem Mehrkampf über '||p_duration||' Tage eingeladen. Nimm die Einladung in der Arena an oder lehne sie ab.',
   '/arena.html'
  from pg_catalog.unnest(p_boxers) id;
 end if;
 return result;
end$function$;

-- ---------------------------------------------------------------------------
-- Arena absagen (nur ohne gespeicherte Ergebnisse)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION league_v21_private.arena_cancel_core(p_arena uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
declare actor public.profiles%rowtype; d public.league_arena_duels_v21%rowtype;
begin
 select * into actor from public.profiles p where p.auth_user_id=(select auth.uid()) and p.is_active and p.role='admin';
 if not found then raise exception 'Nur aktive Admins dürfen eine Arena absagen' using errcode='42501';end if;
 select * into d from public.league_arena_duels_v21 where id=p_arena for update;
 if not found then raise exception 'Arena nicht gefunden' using errcode='P0002';end if;
 if d.status='cancelled' then return pg_catalog.jsonb_build_object('status','cancelled','unchanged',true);end if;
 if d.status='settled' then raise exception 'Gewertete Arenen bleiben als Historie erhalten' using errcode='22023';end if;
 if exists(select 1 from public.league_arena_results_v21 r where r.arena_id=d.id) then
  raise exception 'Arena hat bereits Ergebnisse und kann nicht abgesagt werden' using errcode='23514';end if;
 update public.league_arena_duels_v21 set status='cancelled' where id=d.id;
 if league_v21_private.notifications_enabled() then
  insert into public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
  select m.boxer_id,'boxer_duel',pg_catalog.left('Arena «'||d.title||'» abgesagt',160),
   'Die Arena wurde vom Admin abgesagt. Es werden keine Punkte oder EXP vergeben oder abgezogen.','/arena.html'
  from public.league_arena_members_v21 m where m.arena_id=d.id and m.status in ('invited','accepted');
 end if;
 return pg_catalog.jsonb_build_object('status','cancelled','previous',d.status);
end$fn$;

REVOKE ALL ON FUNCTION league_v21_private.global_draft_update_core(uuid,text,text,text,numeric,timestamptz,timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION league_v21_private.global_publish_core(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION league_v21_private.global_delete_draft_core(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION league_v21_private.arena_cancel_core(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION league_v21_private.global_draft_update_core(uuid,text,text,text,numeric,timestamptz,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.global_publish_core(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.global_delete_draft_core(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.arena_cancel_core(uuid) TO authenticated;

-- Öffentliche Wrapper im bestehenden Muster (SECURITY INVOKER, Prüfung im Kern).
CREATE OR REPLACE FUNCTION public.league_v21_admin_update_global_draft(
 p_challenge uuid, p_title text, p_description text, p_metric text, p_target numeric,
 p_starts timestamp with time zone, p_ends timestamp with time zone)
RETURNS jsonb LANGUAGE sql SET search_path = ''
AS $fn$ select league_v21_private.global_draft_update_core(p_challenge,p_title,p_description,p_metric,p_target,p_starts,p_ends) $fn$;
CREATE OR REPLACE FUNCTION public.league_v21_admin_publish_global_challenge(p_challenge uuid)
RETURNS jsonb LANGUAGE sql SET search_path = ''
AS $fn$ select league_v21_private.global_publish_core(p_challenge) $fn$;
CREATE OR REPLACE FUNCTION public.league_v21_admin_delete_global_draft(p_challenge uuid)
RETURNS text LANGUAGE sql SET search_path = ''
AS $fn$ select league_v21_private.global_delete_draft_core(p_challenge) $fn$;
CREATE OR REPLACE FUNCTION public.league_v21_arena_cancel(p_arena uuid)
RETURNS jsonb LANGUAGE sql SET search_path = ''
AS $fn$ select league_v21_private.arena_cancel_core(p_arena) $fn$;

REVOKE ALL ON FUNCTION public.league_v21_admin_update_global_draft(uuid,text,text,text,numeric,timestamptz,timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.league_v21_admin_publish_global_challenge(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.league_v21_admin_delete_global_draft(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.league_v21_arena_cancel(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.league_v21_admin_update_global_draft(uuid,text,text,text,numeric,timestamptz,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.league_v21_admin_publish_global_challenge(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.league_v21_admin_delete_global_draft(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.league_v21_arena_cancel(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
