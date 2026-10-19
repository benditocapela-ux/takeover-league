-- Only after explicit owner authorisation. Reverses roles and coach RLS without changing data.
-- Preserve admin-only business logic, scores, audit and training data.
BEGIN;
DO $policy$ BEGIN IF to_regclass('public.boxer_achievements') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_boxer_achievements_read_enabled" ON public.boxer_achievements;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.boxer_coach_feedback') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_feedback_insert_admin_enabled" ON public.boxer_coach_feedback;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.boxer_coach_feedback') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_feedback_select_enabled" ON public.boxer_coach_feedback;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.boxer_coach_goals') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_coach_goals_insert_enabled" ON public.boxer_coach_goals;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.boxer_coach_goals') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_coach_goals_select_enabled" ON public.boxer_coach_goals;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.boxer_duels') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_boxer_duels_select_enabled" ON public.boxer_duels;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.league_challenge_participants') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_league_challenge_participants_select_enabled" ON public.league_challenge_participants;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.league_challenges') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_league_challenges_select_enabled" ON public.league_challenges;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.league_season_results') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_league_season_results_select_enabled" ON public.league_season_results;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.league_seasons') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_league_seasons_select_enabled" ON public.league_seasons;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.point_transactions') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_transactions_own_or_admin_read" ON public.point_transactions;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.training_submissions') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_submissions_own_or_admin_read" ON public.training_submissions;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.training_types') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_training_types_visible" ON public.training_types;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.boxer_coach_feedback') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_boxer_coach_feedback_update" ON public.boxer_coach_feedback;$ddl$; END IF; END $policy$;
DO $policy$ BEGIN IF to_regclass('public.boxer_coach_goals') IS NOT NULL THEN EXECUTE $ddl$DROP POLICY IF EXISTS "coach_v3_boxer_coach_goals_update" ON public.boxer_coach_goals;$ddl$; END IF; END $policy$;
CREATE OR REPLACE FUNCTION public.admin_edit_training(p_submission_id uuid, p_boxer_id uuid, p_training_type_id bigint, p_training_date date, p_notes text, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_admin public.profiles%rowtype;
 v_old public.training_submissions%rowtype;
 v_new public.training_submissions%rowtype;
 v_old_tx jsonb;
 v_new_tx jsonb;
 v_points integer;
 v_tx_id uuid;
BEGIN
 SELECT * INTO v_admin FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Admins dürfen Trainings bearbeiten'; END IF;
 IF p_status NOT IN ('pending','approved','rejected') OR p_status IS NULL THEN
  RAISE EXCEPTION 'Ungültiger Status';
 END IF;
 IF p_boxer_id IS NULL OR p_training_type_id IS NULL OR p_training_date IS NULL THEN
  RAISE EXCEPTION 'Boxer, Trainingsart und Datum sind erforderlich';
 END IF;
 PERFORM 1 FROM public.profiles WHERE id=p_boxer_id AND role='boxer';
 IF NOT FOUND THEN RAISE EXCEPTION 'Boxer nicht gefunden'; END IF;
 SELECT points INTO v_points FROM public.training_types
 WHERE id=p_training_type_id AND is_active=true;
 IF NOT FOUND OR v_points IS NULL OR v_points<0 THEN
  RAISE EXCEPTION 'Trainingsart ungültig oder inaktiv';
 END IF;

 SELECT * INTO v_old FROM public.training_submissions
 WHERE id=p_submission_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden'; END IF;

 SELECT id INTO v_tx_id FROM public.point_transactions
 WHERE submission_id=p_submission_id ORDER BY created_at LIMIT 1 FOR UPDATE;
 SELECT to_jsonb(t) INTO v_old_tx FROM public.point_transactions t WHERE id=v_tx_id;
 IF (SELECT count(*) FROM public.point_transactions WHERE submission_id=p_submission_id)>1 THEN
  RAISE EXCEPTION 'Mehrere Punktebuchungen vorhanden: manuelle Prüfung erforderlich';
 END IF;

 UPDATE public.training_submissions SET
 boxer_id=p_boxer_id, training_type_id=p_training_type_id,
 training_date=p_training_date, notes=p_notes,
 status=p_status,
 reviewed_by=CASE WHEN p_status='pending' THEN null ELSE v_admin.id END,
 reviewed_at=CASE WHEN p_status='pending' THEN null ELSE now() END
 WHERE id=p_submission_id RETURNING * INTO v_new;

 IF v_tx_id IS NOT NULL THEN
  UPDATE public.point_transactions SET
   boxer_id=p_boxer_id,
   points=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   exp=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   effective_date=p_training_date,
   created_by=v_admin.id,
   description=CASE WHEN p_status='approved' THEN 'Training (admin-korrigiert)' ELSE 'Training (widerrufen)' END
  WHERE id=v_tx_id;
 ELSIF p_status='approved' THEN
  INSERT INTO public.point_transactions
  (boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
  VALUES (p_boxer_id,p_submission_id,v_points,v_points,'training',
          'Training (admin-korrigiert)',p_training_date,v_admin.id)
  RETURNING id INTO v_tx_id;
 END IF;
 SELECT to_jsonb(t) INTO v_new_tx FROM public.point_transactions t WHERE id=v_tx_id;
 INSERT INTO public.training_audit
 (submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
 VALUES (p_submission_id,v_admin.id,to_jsonb(v_old),to_jsonb(v_new),v_old_tx,v_new_tx);

 -- Recalculate both sides of a transfer, and the affected dates/streaks.
 PERFORM public.recalculate_boxer_bonuses(v_old.boxer_id);
 IF v_old.boxer_id IS DISTINCT FROM p_boxer_id THEN
   PERFORM public.recalculate_boxer_bonuses(p_boxer_id);
 END IF;

 RETURN jsonb_build_object('status',p_status,
  'points',CASE WHEN p_status='approved' THEN v_points ELSE 0 END);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_undo_recent_rejection(p_submission_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 actor public.profiles%rowtype;
 training public.training_submissions%rowtype;
 restored public.training_submissions%rowtype;
begin
 select * into actor from public.profiles p
 where p.auth_user_id=(select auth.uid()) and p.role='admin' and p.is_active=true;
 if not found then raise exception 'Only active admin' using errcode='42501'; end if;
 if p_submission_id is null then raise exception 'Submission required' using errcode='22023';end if;
 select * into training from public.training_submissions s
 where s.id=p_submission_id for update;
 if not found then raise exception 'Training not found' using errcode='22023';end if;
 if training.status<>'rejected' or training.reviewed_by is distinct from actor.id
    or training.reviewed_at is null or training.reviewed_at < now()-interval '15 minutes'
    or training.reviewed_at > now()+interval '1 minute'
 then raise exception 'Only own recent rejections can be undone' using errcode='42501';end if;
 if exists(select 1 from public.point_transactions t
  where t.submission_id=training.id)
 then raise exception 'Training has an existing ledger, use audited admin correction' using errcode='42501';end if;
 update public.training_submissions s
 set status='pending',reviewed_by=null,reviewed_at=null
 where s.id=training.id and s.status='rejected'
 returning * into restored;
 if not found then raise exception 'Concurrent modification' using errcode='40001';end if;
 insert into public.training_audit(submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
 values(training.id,actor.id,to_jsonb(training),to_jsonb(restored),
   (select to_jsonb(t) from public.point_transactions t where t.submission_id=training.id limit 1),
   (select to_jsonb(t) from public.point_transactions t where t.submission_id=training.id limit 1));
 return pg_catalog.jsonb_build_object('submission_id',training.id,'status','pending','undo','rejection_only');
end;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_add_boxer_palmares(p_boxer_id uuid, p_title text, p_event_name text DEFAULT ''::text, p_achievement_type text DEFAULT 'other'::text, p_result text DEFAULT ''::text, p_achievement_date date DEFAULT NULL::date, p_description text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_admin_id uuid; v_entry_id uuid;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() THEN
  RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 SELECT id INTO v_admin_id FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active;
 IF v_admin_id IS NULL THEN
  RAISE EXCEPTION 'Kein aktiver Coach' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags
                WHERE feature_key='palmares' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Palmares ist nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_boxer_id IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.profiles WHERE id=p_boxer_id AND role='boxer' AND is_active
 ) THEN
  RAISE EXCEPTION 'Aktiver Boxer nicht gefunden' USING ERRCODE='22023';
 END IF;
 IF p_title IS NULL OR length(btrim(p_title)) NOT BETWEEN 1 AND 160
    OR p_event_name IS NULL OR length(p_event_name)>160
    OR p_achievement_type IS NULL OR p_achievement_type NOT IN ('fight','tournament','title','medal','other')
    OR p_result IS NULL OR length(p_result)>160
    OR p_description IS NULL OR length(p_description)>4000 THEN
  RAISE EXCEPTION 'Ungueltige Palmares-Angaben' USING ERRCODE='22023';
 END IF;
 INSERT INTO public.boxer_palmares
  (boxer_id,title,event_name,achievement_type,result,achievement_date,description,created_by)
 VALUES
  (p_boxer_id,btrim(p_title),p_event_name,p_achievement_type,p_result,p_achievement_date,p_description,v_admin_id)
 RETURNING id INTO v_entry_id;
 RETURN v_entry_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_add_hall_of_fame_entry(p_boxer_id uuid, p_title text, p_description text DEFAULT ''::text, p_award_category text DEFAULT 'special'::text, p_season_id uuid DEFAULT NULL::uuid, p_awarded_on date DEFAULT CURRENT_DATE)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_admin_id uuid; v_entry_id uuid; v_title text := btrim(coalesce(p_title,''));
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() THEN
  RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 SELECT id INTO v_admin_id FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active;
 IF v_admin_id IS NULL THEN RAISE EXCEPTION 'Kein aktiver Coach' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='hall_of_fame' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Hall of Fame ist noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_boxer_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=p_boxer_id AND role='boxer') THEN
  RAISE EXCEPTION 'Boxer nicht gefunden' USING ERRCODE='22023';
 END IF;
 IF length(v_title) NOT BETWEEN 1 AND 120 OR length(coalesce(p_description,''))>4000 THEN
  RAISE EXCEPTION 'Ungueltiger Titel oder Beschreibung' USING ERRCODE='22023';
 END IF;
 IF p_award_category IS NULL OR p_award_category NOT IN ('season_winner','milestone','special','legacy') THEN
  RAISE EXCEPTION 'Ungueltige Kategorie' USING ERRCODE='22023';
 END IF;
 IF p_awarded_on IS NULL THEN RAISE EXCEPTION 'Datum fehlt' USING ERRCODE='22023'; END IF;
 IF p_award_category='season_winner' AND p_season_id IS NULL THEN
  RAISE EXCEPTION 'Saisonsieger braucht Saison' USING ERRCODE='22023';
 END IF;
 IF p_season_id IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM public.league_seasons WHERE id=p_season_id AND status='completed'
 ) THEN
  RAISE EXCEPTION 'Saison fehlt oder ist nicht abgeschlossen' USING ERRCODE='22023';
 END IF;
 -- Advisory Lock serialisiert doppelte parallele Vergaben fuer dieselbe Kombination.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_boxer_id::text || ':' ||
   coalesce(p_season_id::text,'-') || ':' || p_award_category || ':' || lower(v_title),0));
 IF EXISTS (SELECT 1 FROM public.league_hall_of_fame
   WHERE boxer_id=p_boxer_id AND season_id IS NOT DISTINCT FROM p_season_id
     AND award_category=p_award_category AND lower(title)=lower(v_title)) THEN
  RAISE EXCEPTION 'Ehrung existiert bereits' USING ERRCODE='23505';
 END IF;
 INSERT INTO public.league_hall_of_fame
  (boxer_id,season_id,title,description,award_category,awarded_on,created_by)
 VALUES (p_boxer_id,p_season_id,v_title,coalesce(p_description,''),p_award_category,p_awarded_on,v_admin_id)
 RETURNING id INTO v_entry_id;
 RETURN v_entry_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_award_season_hall_of_fame(p_season_id uuid)
 RETURNS TABLE(season_id uuid, winner_count integer, created_entries integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_season public.league_seasons%ROWTYPE;
 v_admin_id uuid;
 v_winners integer;
 v_created integer;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() THEN
  RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 SELECT p.id INTO v_admin_id FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role='admin' AND p.is_active;
 IF v_admin_id IS NULL THEN
  RAISE EXCEPTION 'Kein aktiver Coach' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags
                WHERE feature_key='seasons' AND is_enabled=true)
    OR NOT EXISTS (SELECT 1 FROM public.league_feature_flags
                   WHERE feature_key='hall_of_fame' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Seasons und Hall of Fame muessen freigeschaltet sein' USING ERRCODE='42501';
 END IF;
 IF p_season_id IS NULL THEN
  RAISE EXCEPTION 'Saison-ID fehlt' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_season FROM public.league_seasons s
 WHERE s.id=p_season_id FOR UPDATE;
 IF NOT FOUND OR v_season.status<>'completed' THEN
  RAISE EXCEPTION 'Saison nicht gefunden oder nicht abgeschlossen' USING ERRCODE='22023';
 END IF;
 SELECT count(*)::integer INTO v_winners
 FROM public.league_season_results r
 JOIN public.profiles p ON p.id=r.boxer_id AND p.role='boxer'
 WHERE r.season_id=p_season_id AND r.rank_position=1;
 IF v_winners=0 THEN
  RAISE EXCEPTION 'Keine gueltigen Sieger in den Saisonergebnissen' USING ERRCODE='22023';
 END IF;
 -- Saisonzeilensperre serialisiert wiederholte/parallele Aufrufe dieser Funktion.
 -- Bereits vorhandene Saisonsieger-Ehrungen werden nicht ueberschrieben.
 INSERT INTO public.league_hall_of_fame
   (boxer_id,season_id,title,description,award_category,awarded_on,created_by)
 SELECT r.boxer_id, v_season.id,
        left('Saisonsieger: ' || v_season.name,120),
        'Platz 1 in der Saison ' || v_season.name,
        'season_winner', CURRENT_DATE, v_admin_id
 FROM public.league_season_results r
 JOIN public.profiles p ON p.id=r.boxer_id AND p.role='boxer'
 WHERE r.season_id=v_season.id AND r.rank_position=1
   AND NOT EXISTS (
     SELECT 1 FROM public.league_hall_of_fame h
     WHERE h.season_id=v_season.id AND h.boxer_id=r.boxer_id
       AND h.award_category='season_winner'
   );
 GET DIAGNOSTICS v_created=ROW_COUNT;
 RETURN QUERY SELECT v_season.id,v_winners,v_created;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_create_boxer_duel(p_challenger_id uuid, p_opponent_id uuid, p_title text, p_description text, p_duel_type text, p_starts_on date, p_ends_on date, p_target_value numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_coach_id uuid;v_id uuid;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() THEN RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501'; END IF;
 SELECT id INTO v_coach_id FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active;
 IF v_coach_id IS NULL THEN RAISE EXCEPTION 'Kein aktives Coach-Profil' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='boxer_duels' AND is_enabled=true) THEN RAISE EXCEPTION 'Boxer-Duelle noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_challenger_id IS NULL OR p_opponent_id IS NULL OR p_challenger_id=p_opponent_id
  OR p_title IS NULL OR char_length(btrim(p_title)) NOT BETWEEN 1 AND 120
  OR p_description IS NULL OR char_length(p_description)>4000
  OR p_duel_type IS NULL OR p_duel_type NOT IN ('training_count','jogging_km','technique_minutes','custom')
  OR p_starts_on IS NULL OR p_ends_on IS NULL OR p_ends_on<p_starts_on
  OR (p_target_value IS NOT NULL AND (p_target_value<=0 OR p_target_value>9999999999.99))
  OR (p_duel_type='training_count' AND p_target_value IS NOT NULL AND p_target_value<>trunc(p_target_value))
 THEN RAISE EXCEPTION 'Ungueltige Duell-Daten' USING ERRCODE='22023'; END IF;
 IF (SELECT count(*) FROM public.profiles WHERE id IN (p_challenger_id,p_opponent_id) AND role='boxer' AND is_active)<>2 THEN
  RAISE EXCEPTION 'Beide Boxer muessen aktive Boxerprofile sein' USING ERRCODE='22023'; END IF;
 INSERT INTO public.boxer_duels(created_by,challenger_id,opponent_id,title,description,duel_type,starts_on,ends_on,target_value,status)
 VALUES(v_coach_id,p_challenger_id,p_opponent_id,btrim(p_title),p_description,p_duel_type,p_starts_on,p_ends_on,p_target_value,'draft') RETURNING id INTO v_id;
 RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_create_league_challenge(p_title text, p_description text, p_starts_on date, p_ends_on date, p_challenge_type text, p_target_value numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_coach_id uuid; v_id uuid;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() THEN
   RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='league_challenges' AND is_enabled=true) THEN
   RAISE EXCEPTION 'Liga-Challenges sind noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 SELECT p.id INTO v_coach_id FROM public.profiles p
  WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role='admin' AND p.is_active;
 IF v_coach_id IS NULL THEN
   RAISE EXCEPTION 'Kein aktives Coach-Profil' USING ERRCODE='42501';
 END IF;
 IF p_title IS NULL OR char_length(btrim(p_title)) NOT BETWEEN 1 AND 120
   OR p_description IS NULL OR char_length(p_description)>4000
   OR p_starts_on IS NULL OR p_ends_on IS NULL OR p_ends_on<p_starts_on
   OR p_challenge_type IS NULL OR p_challenge_type NOT IN
      ('participation','training_count','jogging_km','technique_minutes','custom')
   OR (p_target_value IS NOT NULL AND (p_target_value<=0 OR p_target_value>9999999999.99))
   OR (p_challenge_type IN ('training_count','jogging_km','technique_minutes','custom') AND p_target_value IS NULL)
   OR (p_challenge_type='training_count' AND p_target_value<>trunc(p_target_value)) THEN
   RAISE EXCEPTION 'Ungueltige Challenge-Daten' USING ERRCODE='22023';
 END IF;
 INSERT INTO public.league_challenges
   (created_by,title,description,starts_on,ends_on,challenge_type,target_value,status)
 VALUES (v_coach_id,btrim(p_title),p_description,p_starts_on,p_ends_on,
         p_challenge_type,p_target_value,'draft') RETURNING id INTO v_id;
 RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_create_league_season(p_name text, p_starts_on date, p_ends_on date, p_description text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_admin_id uuid; v_new_id uuid;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() THEN
  RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 SELECT id INTO v_admin_id FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active;
 IF v_admin_id IS NULL THEN RAISE EXCEPTION 'Aktives Coach-Profil fehlt' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='seasons' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Seasons ist noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 1 AND 120
    OR p_description IS NULL OR char_length(p_description)>4000
    OR p_starts_on IS NULL OR p_ends_on IS NULL OR p_ends_on<p_starts_on THEN
  RAISE EXCEPTION 'Ungueltiger Saisonname, Beschreibung oder Zeitraum' USING ERRCODE='22023';
 END IF;
 -- Verhindert paralleles Erstellen ueberschneidender Saisons durch diesen RPC.
 PERFORM pg_advisory_xact_lock(2026,21);
 IF EXISTS (SELECT 1 FROM public.league_seasons s
  WHERE s.status<>'cancelled' AND s.starts_on<=p_ends_on AND s.ends_on>=p_starts_on) THEN
  RAISE EXCEPTION 'Der Saisonzeitraum ueberschneidet sich mit einer bestehenden Saison' USING ERRCODE='22023';
 END IF;
 INSERT INTO public.league_seasons(name,description,starts_on,ends_on,status,created_by)
 VALUES (btrim(p_name),p_description,p_starts_on,p_ends_on,'draft',v_admin_id)
 RETURNING id INTO v_new_id;
 RETURN v_new_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_finalize_boxer_duel(p_duel_id uuid)
 RETURNS TABLE(duel_id uuid, final_status text, winner_id uuid, challenger_score numeric, opponent_score numeric, is_tie boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_duel public.boxer_duels%ROWTYPE; v_score record;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() OR NOT EXISTS (
  SELECT 1 FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active
 ) THEN RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='boxer_duels' AND is_enabled=true)
 THEN RAISE EXCEPTION 'Boxer-Duelle noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_duel_id IS NULL THEN RAISE EXCEPTION 'Duell-ID fehlt' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_duel FROM public.boxer_duels WHERE id=p_duel_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duell nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF v_duel.status='completed' THEN
  RETURN QUERY SELECT v_duel.id,v_duel.status,v_duel.winner_id,
   v_duel.challenger_progress,v_duel.opponent_progress,
   (v_duel.challenger_progress=v_duel.opponent_progress);
  RETURN;
 END IF;
 IF v_duel.status<>'active' THEN
  RAISE EXCEPTION 'Nur aktive Duelle koennen abgeschlossen werden' USING ERRCODE='22023'; END IF;
 IF CURRENT_DATE<=v_duel.ends_on THEN
  RAISE EXCEPTION 'Duellzeitraum noch nicht abgeschlossen' USING ERRCODE='22023'; END IF;
 IF v_duel.duel_type='custom' THEN
  RAISE EXCEPTION 'Custom-Duelle benoetigen eine eigene Bewertungsregel' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_score FROM public.get_boxer_duel_score(p_duel_id);
 IF NOT FOUND THEN RAISE EXCEPTION 'Auswertung fehlgeschlagen'; END IF;
 UPDATE public.boxer_duels d SET
  challenger_progress=v_score.challenger_progress,
  opponent_progress=v_score.opponent_progress,
  winner_id=v_score.leading_boxer_id,
  status='completed',updated_at=now()
 WHERE d.id=p_duel_id;
 RETURN QUERY SELECT v_duel.id,'completed'::text,v_score.leading_boxer_id,
  v_score.challenger_progress,v_score.opponent_progress,v_score.is_tie;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_finalize_league_season(p_season_id uuid)
 RETURNS TABLE(season_id uuid, boxer_count integer, final_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_season public.league_seasons%ROWTYPE; v_count integer;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() OR NOT EXISTS (
  SELECT 1 FROM public.profiles
  WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active
 ) THEN
  RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags
                WHERE feature_key='seasons' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Seasons ist noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_season_id IS NULL THEN RAISE EXCEPTION 'Saison-ID fehlt' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_season FROM public.league_seasons WHERE id=p_season_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Saison nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF v_season.status='completed' THEN
  RETURN QUERY SELECT v_season.id,
    (SELECT count(*)::integer FROM public.league_season_results r WHERE r.season_id=v_season.id),
    'completed'::text;
  RETURN;
 END IF;
 IF v_season.status<>'active' THEN
  RAISE EXCEPTION 'Nur aktive Saisons koennen abgeschlossen werden' USING ERRCODE='22023';
 END IF;
 IF CURRENT_DATE<=v_season.ends_on THEN
  RAISE EXCEPTION 'Saisonzeitraum noch nicht abgeschlossen' USING ERRCODE='22023';
 END IF;
 IF EXISTS (SELECT 1 FROM public.league_season_results WHERE season_id=v_season.id) THEN
  RAISE EXCEPTION 'Bereits vorhandene Saisonergebnisse: manueller Abgleich erforderlich';
 END IF;

 WITH ledger AS (
  SELECT t.boxer_id,
    GREATEST(0,COALESCE(SUM(t.points),0))::integer AS season_points,
    GREATEST(0,COALESCE(SUM(t.exp),0))::integer AS season_exp
  FROM public.point_transactions t
  WHERE t.effective_date BETWEEN v_season.starts_on AND v_season.ends_on
    AND t.category <> 'legacy_import'
  GROUP BY t.boxer_id
 ), training AS (
  SELECT s.boxer_id, COUNT(*)::integer AS approved_trainings
  FROM public.training_submissions s
  WHERE s.status='approved'
    AND s.training_date BETWEEN v_season.starts_on AND v_season.ends_on
  GROUP BY s.boxer_id
 ), combined AS (
  SELECT p.id AS boxer_id,
   COALESCE(l.season_points,0) AS season_points,
   COALESCE(l.season_exp,0) AS season_exp,
   COALESCE(tr.approved_trainings,0) AS approved_trainings
  FROM public.profiles p
  LEFT JOIN ledger l ON l.boxer_id=p.id
  LEFT JOIN training tr ON tr.boxer_id=p.id
  WHERE p.role='boxer' AND (l.boxer_id IS NOT NULL OR tr.boxer_id IS NOT NULL)
 ), ranked AS (
  SELECT *, RANK() OVER (
    ORDER BY season_points DESC,season_exp DESC,approved_trainings DESC
  )::integer AS rank_position
  FROM combined
 )
 INSERT INTO public.league_season_results
  (season_id,boxer_id,rank_position,season_points,season_exp,approved_trainings,calculated_at)
 SELECT v_season.id,boxer_id,rank_position,season_points,season_exp,approved_trainings,now()
 FROM ranked;

 GET DIAGNOSTICS v_count = ROW_COUNT;
 UPDATE public.league_seasons SET status='completed',updated_at=now() WHERE id=v_season.id;
 RETURN QUERY SELECT v_season.id,v_count,'completed'::text;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_set_boxer_duel_status(p_duel_id uuid, p_new_status text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_old text;v_starts date;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() OR NOT EXISTS (
  SELECT 1 FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active
 ) THEN RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='boxer_duels' AND is_enabled=true)
 THEN RAISE EXCEPTION 'Boxer-Duelle noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_duel_id IS NULL OR p_new_status IS NULL OR p_new_status NOT IN ('invited','active','cancelled')
 THEN RAISE EXCEPTION 'Fuer completed bitte coach_finalize_boxer_duel verwenden' USING ERRCODE='22023'; END IF;
 SELECT status,starts_on INTO v_old,v_starts FROM public.boxer_duels WHERE id=p_duel_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duell nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF v_old=p_new_status THEN RETURN v_old; END IF;
 IF NOT ((v_old='draft' AND p_new_status IN ('invited','cancelled')) OR
         (v_old='accepted' AND p_new_status IN ('active','cancelled')) OR
         (v_old='active' AND p_new_status='cancelled') OR
         (v_old='invited' AND p_new_status='cancelled')) THEN
  RAISE EXCEPTION 'Statuswechsel % -> % nicht erlaubt',v_old,p_new_status USING ERRCODE='22023'; END IF;
 IF p_new_status='active' AND CURRENT_DATE<v_starts THEN
  RAISE EXCEPTION 'Duell beginnt erst am %',v_starts USING ERRCODE='22023'; END IF;
 UPDATE public.boxer_duels SET status=p_new_status,updated_at=now() WHERE id=p_duel_id;
 RETURN p_new_status;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_set_goal_status(p_goal_id uuid, p_new_status text)
 RETURNS TABLE(goal_id uuid, goal_status text, changed_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_old_status text; v_updated_at timestamptz;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() THEN
  RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags
   WHERE feature_key='coach_goals' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach-Ziele sind noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_goal_id IS NULL OR p_new_status IS NULL
   OR p_new_status NOT IN ('planned','in_progress','completed','cancelled') THEN
  RAISE EXCEPTION 'Ungueltige Eingabe' USING ERRCODE='22023';
 END IF;
 SELECT g.status INTO v_old_status FROM public.boxer_coach_goals g
  WHERE g.id=p_goal_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Ziel nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF v_old_status=p_new_status THEN
  SELECT g.updated_at INTO v_updated_at FROM public.boxer_coach_goals g WHERE g.id=p_goal_id;
 ELSIF (v_old_status='planned' AND p_new_status IN ('in_progress','cancelled'))
    OR (v_old_status='in_progress' AND p_new_status IN ('completed','cancelled')) THEN
  UPDATE public.boxer_coach_goals g
    SET status=p_new_status, updated_at=now()
    WHERE g.id=p_goal_id RETURNING g.updated_at INTO v_updated_at;
 ELSE
  RAISE EXCEPTION 'Statuswechsel % -> % nicht erlaubt', v_old_status, p_new_status
   USING ERRCODE='22023';
 END IF;
 RETURN QUERY SELECT p_goal_id,p_new_status,v_updated_at;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_set_league_challenge_status(p_challenge_id uuid, p_new_status text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_old text;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin()
   OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role='admin' AND p.is_active) THEN
   RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='league_challenges' AND is_enabled=true) THEN
   RAISE EXCEPTION 'Liga-Challenges sind noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_challenge_id IS NULL OR p_new_status IS NULL
   OR p_new_status NOT IN ('draft','scheduled','active','completed','cancelled') THEN
   RAISE EXCEPTION 'Ungueltige Eingabe' USING ERRCODE='22023';
 END IF;
 SELECT c.status INTO v_old FROM public.league_challenges c
  WHERE c.id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF v_old=p_new_status THEN RETURN v_old; END IF;
 IF NOT (
   (v_old='draft' AND p_new_status IN ('scheduled','cancelled')) OR
   (v_old='scheduled' AND p_new_status IN ('active','cancelled')) OR
   (v_old='active' AND p_new_status IN ('completed','cancelled'))
 ) THEN
   RAISE EXCEPTION 'Statuswechsel % -> % nicht erlaubt',v_old,p_new_status USING ERRCODE='22023';
 END IF;
 UPDATE public.league_challenges c SET status=p_new_status,updated_at=now()
  WHERE c.id=p_challenge_id;
 RETURN p_new_status;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_set_league_season_status(p_season_id uuid, p_new_status text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_old_status text; v_start date; v_end date;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() OR NOT EXISTS (
  SELECT 1 FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active
 ) THEN RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='seasons' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Seasons ist noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_season_id IS NULL OR p_new_status IS NULL OR p_new_status NOT IN ('scheduled','active','cancelled') THEN
  RAISE EXCEPTION 'Status ungueltig. Abschluss erfolgt spaeter ueber Saison-Auswertung.' USING ERRCODE='22023';
 END IF;
 SELECT status,starts_on,ends_on INTO v_old_status,v_start,v_end
 FROM public.league_seasons WHERE id=p_season_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Saison nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF v_old_status=p_new_status THEN RETURN v_old_status; END IF;
 IF NOT ((v_old_status='draft' AND p_new_status IN ('scheduled','cancelled'))
  OR (v_old_status='scheduled' AND p_new_status IN ('active','cancelled'))
  OR (v_old_status='active' AND p_new_status='cancelled')) THEN
  RAISE EXCEPTION 'Statuswechsel % -> % nicht erlaubt',v_old_status,p_new_status USING ERRCODE='22023';
 END IF;
 IF p_new_status='active' AND (CURRENT_DATE<v_start OR CURRENT_DATE>v_end) THEN
  RAISE EXCEPTION 'Saison kann nur innerhalb ihres Zeitraums aktiviert werden' USING ERRCODE='22023';
 END IF;
 UPDATE public.league_seasons SET status=p_new_status,updated_at=now() WHERE id=p_season_id;
 RETURN p_new_status;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_training_audit_recent(p_limit integer DEFAULT 50)
 RETURNS TABLE(audit_id bigint, happened_at timestamp with time zone, boxer_name text, changed_by_name text, old_status text, new_status text, old_points integer, new_points integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (
    select 1 from public.profiles actor
    where actor.auth_user_id = (select auth.uid())
      and actor.role = 'admin' and actor.is_active is true
  ) then
    raise exception 'Only an active admin can read training audit'
      using errcode = '42501';
  end if;

  return query
  select a.id, a.changed_at, boxer.display_name::text, editor.display_name::text,
    a.old_submission ->> 'status',
    a.new_submission ->> 'status',
    nullif(a.old_transaction ->> 'points','')::integer,
    nullif(a.new_transaction ->> 'points','')::integer
  from public.training_audit a
  left join public.training_submissions s on s.id = a.submission_id
  left join public.profiles boxer on boxer.id = coalesce(
    s.boxer_id,
    nullif(a.new_submission ->> 'boxer_id','')::uuid,
    nullif(a.old_submission ->> 'boxer_id','')::uuid)
  left join public.profiles editor on editor.id = a.changed_by
  order by a.changed_at desc, a.id desc
  limit greatest(1, least(coalesce(p_limit,50),100));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.coach_upsert_achievement_definition(p_code text, p_title text, p_description text DEFAULT ''::text, p_category text DEFAULT 'general'::text, p_icon_key text DEFAULT NULL::text, p_is_active boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id uuid;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.is_league_admin() THEN
  RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='achievements' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Achievements sind noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_code IS NULL OR p_code !~ '^[a-z][a-z0-9_]{1,63}$'
 OR p_title IS NULL OR char_length(btrim(p_title)) NOT BETWEEN 1 AND 120
 OR p_description IS NULL OR char_length(p_description)>1000
 OR p_category IS NULL OR char_length(p_category) NOT BETWEEN 1 AND 60
 OR (p_icon_key IS NOT NULL AND char_length(p_icon_key)>120)
 OR p_is_active IS NULL THEN
  RAISE EXCEPTION 'Ungueltige Achievement-Definition' USING ERRCODE='22023';
 END IF;
 INSERT INTO public.achievement_definitions(code,title,description,category,icon_key,is_active)
 VALUES (p_code,btrim(p_title),p_description,p_category,p_icon_key,p_is_active)
 ON CONFLICT(code) DO UPDATE SET title=excluded.title,description=excluded.description,
  category=excluded.category,icon_key=excluded.icon_key,is_active=excluded.is_active
 RETURNING id INTO v_id;
 RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_boxer_duel_score(p_duel_id uuid)
 RETURNS TABLE(duel_id uuid, challenger_id uuid, opponent_id uuid, challenger_progress numeric, opponent_progress numeric, leading_boxer_id uuid, is_tie boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_duel public.boxer_duels%ROWTYPE;
 v_caller uuid;
 v_admin boolean;
 v_challenger numeric := 0;
 v_opponent numeric := 0;
BEGIN
 v_caller := (SELECT auth.uid());
 IF v_caller IS NULL THEN
   RAISE EXCEPTION 'Nicht angemeldet' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='boxer_duels' AND is_enabled=true) THEN
   RAISE EXCEPTION 'Boxer-Duelle noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF p_duel_id IS NULL THEN RAISE EXCEPTION 'Duell-ID fehlt' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_duel FROM public.boxer_duels d WHERE d.id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duell nicht gefunden' USING ERRCODE='P0002'; END IF;
 v_admin := public.is_league_admin() AND EXISTS (
   SELECT 1 FROM public.profiles p WHERE p.auth_user_id=v_caller AND p.role='admin' AND p.is_active
 );
 IF NOT v_admin AND NOT EXISTS (
   SELECT 1 FROM public.profiles p
   WHERE p.auth_user_id=v_caller AND p.role='boxer' AND p.is_active
     AND p.id IN (v_duel.challenger_id,v_duel.opponent_id)
 ) THEN RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501'; END IF;
 IF v_duel.duel_type='custom' THEN
   RAISE EXCEPTION 'Custom-Duelle benoetigen eine separate Bewertungsregel' USING ERRCODE='22023';
 END IF;
 -- Ausschliesslich bestaetigte Trainings im festgelegten Zeitraum.
 -- Bei Jogging/Technik werden die zugehoerigen Trainingsarten beruecksichtigt.
 SELECT
   COALESCE(sum(CASE WHEN s.boxer_id=v_duel.challenger_id THEN
     CASE v_duel.duel_type
       WHEN 'training_count' THEN 1::numeric
       WHEN 'jogging_km' THEN COALESCE(s.jogging_km,0)
       WHEN 'technique_minutes' THEN COALESCE(s.technique_minutes,0)
       ELSE 0::numeric END ELSE 0::numeric END),0),
   COALESCE(sum(CASE WHEN s.boxer_id=v_duel.opponent_id THEN
     CASE v_duel.duel_type
       WHEN 'training_count' THEN 1::numeric
       WHEN 'jogging_km' THEN COALESCE(s.jogging_km,0)
       WHEN 'technique_minutes' THEN COALESCE(s.technique_minutes,0)
       ELSE 0::numeric END ELSE 0::numeric END),0)
 INTO v_challenger,v_opponent
 FROM public.training_submissions s
 JOIN public.training_types t ON t.id=s.training_type_id
 WHERE s.boxer_id IN (v_duel.challenger_id,v_duel.opponent_id)
   AND s.status='approved'
   AND s.training_date BETWEEN v_duel.starts_on AND v_duel.ends_on
   AND (
     v_duel.duel_type='training_count'
     OR (v_duel.duel_type='jogging_km' AND t.name ~* '(jogg|lauf|running)')
     OR (v_duel.duel_type='technique_minutes' AND t.name ~* 'technik')
   );
 RETURN QUERY SELECT v_duel.id,v_duel.challenger_id,v_duel.opponent_id,
   v_challenger,v_opponent,
   CASE WHEN v_challenger>v_opponent THEN v_duel.challenger_id
        WHEN v_opponent>v_challenger THEN v_duel.opponent_id
        ELSE NULL::uuid END,
   v_challenger=v_opponent;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_boxer_exp_level_rank(p_boxer_id uuid)
 RETURNS TABLE(boxer_id uuid, lifetime_exp bigint, lifetime_points bigint, level_number integer, level_start_exp bigint, next_level_exp bigint, exp_into_level bigint, exp_to_next_level bigint, rank_letter text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
WITH RECURSIVE allowed AS (
 SELECT p.id FROM public.profiles p
 WHERE p.id=p_boxer_id AND p.role='boxer' AND p.is_active
  AND EXISTS (SELECT 1 FROM public.league_feature_flags f
              WHERE f.feature_key='performance_dashboard' AND f.is_enabled)
  AND EXISTS (SELECT 1 FROM public.profiles viewer
              WHERE viewer.auth_user_id=(SELECT auth.uid()) AND viewer.is_active
                AND (viewer.id=p.id OR viewer.role='admin'))
), totals AS (
 SELECT a.id, GREATEST(0::bigint,COALESCE(SUM(t.exp),0)::bigint) AS exp,
        GREATEST(0::bigint,COALESCE(SUM(t.points),0)::bigint) AS points
 FROM allowed a LEFT JOIN public.point_transactions t ON t.boxer_id=a.id
 GROUP BY a.id
), levels AS (
 SELECT 1::integer AS lvl, 0::bigint AS start_exp, 100::bigint AS step_exp
 UNION ALL
 SELECT lvl+1, start_exp+step_exp, CEIL(step_exp::numeric*1.15)::bigint
 FROM levels WHERE lvl<150
), selected AS (
 SELECT t.id,t.exp,t.points,l.lvl,l.start_exp,l.step_exp
 FROM totals t CROSS JOIN LATERAL (
  SELECT lvl,start_exp,step_exp FROM levels
  WHERE start_exp<=t.exp ORDER BY lvl DESC LIMIT 1
 ) l
)
SELECT s.id,s.exp,s.points,s.lvl,s.start_exp,
       (s.start_exp+s.step_exp)::bigint,
       (s.exp-s.start_exp)::bigint,
       GREATEST(0::bigint,s.start_exp+s.step_exp-s.exp)::bigint,
       CASE WHEN s.exp>=94500 THEN 'S' WHEN s.exp>=46500 THEN 'A'
            WHEN s.exp>=22500 THEN 'B' WHEN s.exp>=10500 THEN 'C'
            WHEN s.exp>=4500 THEN 'D' WHEN s.exp>=1500 THEN 'E' ELSE 'F' END
FROM selected s;
$function$
;

CREATE OR REPLACE FUNCTION public.get_boxer_performance_30d(p_boxer_id uuid, p_period_end date DEFAULT CURRENT_DATE)
 RETURNS TABLE(boxer_id uuid, period_start date, period_end date, approved_sessions bigint, active_days bigint, training_equivalents numeric, distinct_training_types bigint, consistency_score numeric, volume_score numeric, variety_score numeric, total_score numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 WITH permitted AS (
  SELECT p.id FROM public.profiles p
  WHERE p.id=p_boxer_id AND p.role='boxer' AND p.is_active
   AND EXISTS (
    SELECT 1 FROM public.profiles viewer
    WHERE viewer.auth_user_id=(SELECT auth.uid()) AND viewer.is_active
     AND (viewer.role='admin' OR viewer.id=p.id)
   )
   AND EXISTS (SELECT 1 FROM public.league_feature_flags f
               WHERE f.feature_key='performance_dashboard' AND f.is_enabled)
 ), sessions AS (
  SELECT s.id, s.training_date, s.training_type_id,
   LEAST(2::numeric, GREATEST(0::numeric,
    CASE
     WHEN lower(t.name) ~ '(boxen|boxing)' THEN 1.5::numeric
     WHEN lower(t.name) ~ '(jogg|lauf|running)' THEN COALESCE(s.jogging_km,0)*0.2
     WHEN lower(t.name) ~ 'sprint' THEN 1::numeric
     WHEN lower(t.name) ~ '(technik|technique)' THEN COALESCE(s.technique_minutes,0)/60.0
     ELSE 1::numeric
    END)) AS ve
  FROM public.training_submissions s
  JOIN public.training_types t ON t.id=s.training_type_id
  JOIN permitted p ON p.id=s.boxer_id
  WHERE s.status='approved' AND s.training_date BETWEEN (p_period_end-29) AND p_period_end
 ), aggregate_values AS (
  SELECT count(*)::bigint AS n, count(DISTINCT training_date)::bigint AS days,
   COALESCE(sum(ve),0)::numeric AS ve, count(DISTINCT training_type_id)::bigint AS types
  FROM sessions
 )
 SELECT p.id, (p_period_end-29)::date, p_period_end,
  a.n, a.days, round(a.ve,2), a.types,
  round(LEAST(40::numeric,a.days*40.0/12),2),
  round(LEAST(40::numeric,a.ve*40.0/20),2),
  round(LEAST(20::numeric,a.types*20.0/5),2),
  round(LEAST(40::numeric,a.days*40.0/12)+LEAST(40::numeric,a.ve*40.0/20)+LEAST(20::numeric,a.types*20.0/5),2)
 FROM permitted p CROSS JOIN aggregate_values a;
$function$
;

CREATE OR REPLACE FUNCTION public.get_league_challenge_progress(p_challenge_id uuid, p_boxer_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(challenge_id uuid, boxer_id uuid, challenge_type text, target_value numeric, progress_value numeric, progress_percent numeric, goal_reached boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_boxer uuid; v_type text; v_target numeric; v_start date; v_end date;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.league_feature_flags WHERE feature_key='league_challenges' AND is_enabled=true
 ) THEN RAISE EXCEPTION 'Liga-Challenges sind nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_challenge_id IS NULL THEN RAISE EXCEPTION 'Challenge-ID fehlt' USING ERRCODE='22023'; END IF;
 IF public.is_league_admin() AND EXISTS (
  SELECT 1 FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND role='admin' AND is_active
 ) THEN
  v_boxer:=p_boxer_id;
 ELSE
  SELECT id INTO v_boxer FROM public.profiles
  WHERE auth_user_id=(SELECT auth.uid()) AND role='boxer' AND is_active;
  IF v_boxer IS NULL OR (p_boxer_id IS NOT NULL AND p_boxer_id<>v_boxer) THEN
   RAISE EXCEPTION 'Nicht berechtigt' USING ERRCODE='42501';
  END IF;
 END IF;
 IF v_boxer IS NULL THEN RAISE EXCEPTION 'Boxer-ID fehlt' USING ERRCODE='22023'; END IF;
 SELECT c.challenge_type,c.target_value,c.starts_on,c.ends_on
 INTO v_type,v_target,v_start,v_end FROM public.league_challenges c WHERE c.id=p_challenge_id
 AND c.status IN ('scheduled','active','completed');
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge nicht sichtbar' USING ERRCODE='P0002'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_challenge_participants p
  WHERE p.challenge_id=p_challenge_id AND p.boxer_id=v_boxer AND p.status IN ('joined','completed')) THEN
  RAISE EXCEPTION 'Keine aktive Teilnahme' USING ERRCODE='42501';
 END IF;
 RETURN QUERY
 SELECT p_challenge_id,v_boxer,v_type,v_target,
 CASE v_type
  WHEN 'training_count' THEN count(s.id)::numeric
  WHEN 'participation' THEN count(s.id)::numeric
  WHEN 'jogging_km' THEN coalesce(sum(CASE WHEN lower(t.name) ~ 'jogg|lauf|running' THEN greatest(coalesce(s.jogging_km,0),0) ELSE 0 END),0)::numeric
  WHEN 'technique_minutes' THEN coalesce(sum(CASE WHEN lower(t.name) ~ 'technik|technique' THEN greatest(coalesce(s.technique_minutes,0),0) ELSE 0 END),0)::numeric
  ELSE NULL::numeric
 END AS progress_value,
 CASE WHEN v_target IS NULL OR v_type='custom' THEN NULL::numeric
 ELSE least(100,round((CASE v_type
  WHEN 'training_count' THEN count(s.id)::numeric
  WHEN 'participation' THEN count(s.id)::numeric
  WHEN 'jogging_km' THEN coalesce(sum(CASE WHEN lower(t.name) ~ 'jogg|lauf|running' THEN greatest(coalesce(s.jogging_km,0),0) ELSE 0 END),0)::numeric
  WHEN 'technique_minutes' THEN coalesce(sum(CASE WHEN lower(t.name) ~ 'technik|technique' THEN greatest(coalesce(s.technique_minutes,0),0) ELSE 0 END),0)::numeric
  ELSE 0::numeric END) / nullif(v_target,0) * 100, 2)) END AS progress_percent,
 CASE WHEN v_target IS NULL OR v_type='custom' THEN false
 ELSE (CASE v_type
  WHEN 'training_count' THEN count(s.id)::numeric
  WHEN 'participation' THEN count(s.id)::numeric
  WHEN 'jogging_km' THEN coalesce(sum(CASE WHEN lower(t.name) ~ 'jogg|lauf|running' THEN greatest(coalesce(s.jogging_km,0),0) ELSE 0 END),0)::numeric
  WHEN 'technique_minutes' THEN coalesce(sum(CASE WHEN lower(t.name) ~ 'technik|technique' THEN greatest(coalesce(s.technique_minutes,0),0) ELSE 0 END),0)::numeric
  ELSE 0::numeric END)>=v_target END AS goal_reached
 FROM (SELECT 1) seed
 LEFT JOIN public.training_submissions s ON s.boxer_id=v_boxer AND s.status='approved'
  AND s.training_date BETWEEN v_start AND v_end
 LEFT JOIN public.training_types t ON t.id=s.training_type_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.review_training(p_submission_id uuid, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_admin public.profiles%rowtype;
  v_submission public.training_submissions%rowtype;
  v_points integer;
BEGIN
  SELECT * INTO v_admin
  FROM public.profiles
  WHERE auth_user_id = (SELECT auth.uid())
    AND role = 'admin' AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Nur aktive Admins dürfen Trainings prüfen.';
  END IF;

  IF p_decision IS NULL OR p_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'Ungültige Entscheidung.';
  END IF;

  SELECT * INTO v_submission
  FROM public.training_submissions
  WHERE id = p_submission_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden.'; END IF;
  IF v_submission.status <> 'pending' THEN
    RAISE EXCEPTION 'Dieses Training wurde bereits bearbeitet.';
  END IF;

  IF p_decision = 'approved' THEN
    SELECT points INTO v_points FROM public.training_types
    WHERE id = v_submission.training_type_id;
    IF v_points IS NULL OR v_points < 0 THEN
      RAISE EXCEPTION 'Kein gültiger Punktewert für diese Trainingsart.';
    END IF;
    INSERT INTO public.point_transactions
      (boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
    VALUES
      (v_submission.boxer_id,v_submission.id,v_points,v_points,'training',
       'Bestätigtes Training',v_submission.training_date,v_admin.id);
  END IF;

  UPDATE public.training_submissions
  SET status = p_decision, reviewed_by = v_admin.id, reviewed_at = now()
  WHERE id = v_submission.id;

  -- This runs under the same authenticated admin request, in one transaction.
  PERFORM public.recalculate_boxer_bonuses(v_submission.boxer_id);

  RETURN jsonb_build_object(
    'submission_id',v_submission.id,
    'status',p_decision,
    'points_awarded',CASE WHEN p_decision='approved' THEN v_points ELSE 0 END
  );
END;
$function$
;
DROP FUNCTION IF EXISTS public.coach_list_boxers();
DROP FUNCTION IF EXISTS public.is_league_coach();
DROP FUNCTION IF EXISTS league_private.coach_training_bonus_refresh(uuid);
COMMIT;