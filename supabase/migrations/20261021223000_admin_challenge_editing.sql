-- Admin-only editing for existing coach and global league challenges.
-- Additive RPCs only. No rows, points, EXP, flags or feature data are changed by this migration.
BEGIN;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_admin_edit(
 p_challenge_id uuid,
 p_title text,
 p_description text,
 p_kind text,
 p_duration_days integer,
 p_goal_text text,
 p_reward_exp integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $func$
DECLARE
 a jsonb := league_private.coach_v2_actor();
 c public.league_coach_challenges%ROWTYPE;
 has_entries boolean;
 goal_changed boolean;
 next_goal text;
 next_reward integer;
 next_goal_spec jsonb;
BEGIN
 IF a->>'role' IS DISTINCT FROM 'admin' THEN
  RAISE EXCEPTION 'Nur aktive Admins dürfen Challenges umfassend bearbeiten' USING ERRCODE='42501';
 END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_title,''))) NOT BETWEEN 3 AND 120
    OR char_length(COALESCE(p_description,'')) > 2000
    OR p_kind NOT IN ('individual','competition','coach_goal') OR p_kind IS NULL
    OR p_duration_days NOT IN (7,14,30) OR p_duration_days IS NULL
 THEN
  RAISE EXCEPTION 'Ungültiger Challenge-Titel, Beschreibung, Art oder Dauer' USING ERRCODE='22023';
 END IF;

 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF c.status NOT IN ('draft','open','active','awaiting_reviews') THEN
  RAISE EXCEPTION 'Abgeschlossene oder abgebrochene Challenges sind gesperrt' USING ERRCODE='22023';
 END IF;

 SELECT EXISTS(
  SELECT 1 FROM public.league_coach_challenge_entries e
  WHERE e.challenge_id=c.id AND e.status IN ('joined','completed')
 ) INTO has_entries;
 goal_changed := p_goal_text IS NOT NULL OR p_reward_exp IS NOT NULL;

 IF (c.status IN ('active','awaiting_reviews') OR has_entries)
    AND (p_kind IS DISTINCT FROM c.challenge_kind
      OR p_duration_days IS DISTINCT FROM c.duration_days
      OR goal_changed)
 THEN
  RAISE EXCEPTION 'Art, Dauer, Ziel und EXP sind nach Start oder Teilnahme gesperrt; nur Titel und Beschreibung bleiben änderbar'
   USING ERRCODE='22023';
 END IF;

 next_goal_spec := c.goal_spec;
 IF goal_changed THEN
  next_goal := COALESCE(p_goal_text,c.goal_spec->>'goal_text');
  next_reward := COALESCE(p_reward_exp,NULLIF(c.goal_spec->>'reward_exp','')::integer,25);
  IF char_length(pg_catalog.btrim(COALESCE(next_goal,''))) NOT BETWEEN 5 AND 1000
     OR next_reward NOT IN (25,50,100,150,200)
  THEN
   RAISE EXCEPTION 'Individuelles Ziel muss 5–1000 Zeichen und die Belohnung 25, 50, 100, 150 oder 200 EXP betragen'
    USING ERRCODE='22023';
  END IF;
  next_goal_spec := pg_catalog.jsonb_build_object(
   'version',1,
   'goal_text',pg_catalog.btrim(next_goal),
   'review_mode','manual',
   'reward_exp',next_reward,
   'target_value',NULL,
   'metric',NULL
  );
 END IF;

 UPDATE public.league_coach_challenges
 SET title=pg_catalog.btrim(p_title),
     description=COALESCE(p_description,''),
     challenge_kind=p_kind,
     duration_days=p_duration_days,
     goal_spec=next_goal_spec,
     updated_at=pg_catalog.now()
 WHERE id=c.id;

 RETURN pg_catalog.jsonb_build_object(
  'id',c.id,'status',c.status,'goal_updated',goal_changed,
  'rules_locked',(c.status IN ('active','awaiting_reviews') OR has_entries)
 );
END
$func$;

REVOKE ALL ON FUNCTION public.coach_challenge_v2_admin_edit(uuid,text,text,text,integer,text,integer)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_admin_edit(uuid,text,text,text,integer,text,integer)
 TO authenticated;

CREATE OR REPLACE FUNCTION league_v21_private.global_edit_core(
 p_challenge uuid,
 p_title text,
 p_description text,
 p_metric text,
 p_target numeric,
 p_starts timestamptz,
 p_ends timestamptz,
 p_update_rules boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $func$
DECLARE
 actor public.profiles%ROWTYPE;
 c public.league_global_challenges_v21%ROWTYPE;
 change_rules boolean := COALESCE(p_update_rules,false);
BEGIN
 SELECT * INTO actor
 FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active IS TRUE AND p.role='admin';
 IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Admins dürfen Liga-Challenges bearbeiten' USING ERRCODE='42501'; END IF;

 IF NOT EXISTS(
  SELECT 1 FROM public.league_feature_flags f
  WHERE f.feature_key='league_challenges' AND f.is_enabled IS TRUE
 ) THEN
  RAISE EXCEPTION 'Liga-Challenges sind noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;

 SELECT * INTO c FROM public.league_global_challenges_v21 x WHERE x.id=p_challenge FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Liga-Challenge nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF c.status<>'active' THEN RAISE EXCEPTION 'Nur aktive Liga-Challenges können bearbeitet werden' USING ERRCODE='22023'; END IF;

 IF p_title IS NULL OR pg_catalog.length(pg_catalog.btrim(p_title)) NOT BETWEEN 3 AND 120
    OR pg_catalog.length(COALESCE(p_description,''))>1000
 THEN RAISE EXCEPTION 'Ungültiger Titel oder Beschreibung' USING ERRCODE='22023'; END IF;

 IF change_rules THEN
  IF c.starts_at<=pg_catalog.now() THEN
   RAISE EXCEPTION 'Messwert, Ziel und Zeitraum sind nach Beginn gesperrt' USING ERRCODE='22023';
  END IF;
  IF EXISTS(SELECT 1 FROM public.league_global_entries_v21 e WHERE e.challenge_id=c.id) THEN
   RAISE EXCEPTION 'Messwert, Ziel und Zeitraum sind gesperrt, sobald Boxer beigetreten sind' USING ERRCODE='22023';
  END IF;
  IF p_metric IS NULL OR p_metric NOT IN ('training_sessions','jogging_km','technique_minutes')
     OR p_target IS NULL OR p_target<=0 OR p_target>1000000
     OR p_starts IS NULL OR p_ends IS NULL
     OR p_starts<=pg_catalog.now() OR p_ends<=pg_catalog.now()
     OR p_ends<=p_starts OR p_ends>p_starts+interval '90 days'
  THEN RAISE EXCEPTION 'Ungültiger Messwert, Ziel oder Zeitraum (maximal 90 Tage)' USING ERRCODE='22023'; END IF;

  UPDATE public.league_global_challenges_v21
  SET title=pg_catalog.btrim(p_title),description=COALESCE(pg_catalog.btrim(p_description),''),
      metric=p_metric,target_value=p_target,starts_at=p_starts,ends_at=p_ends
  WHERE id=c.id;
 ELSE
  UPDATE public.league_global_challenges_v21
  SET title=pg_catalog.btrim(p_title),description=COALESCE(pg_catalog.btrim(p_description),'')
  WHERE id=c.id;
 END IF;

 RETURN pg_catalog.jsonb_build_object('id',c.id,'status',c.status,'rules_updated',change_rules);
END
$func$;

REVOKE ALL ON FUNCTION league_v21_private.global_edit_core(uuid,text,text,text,numeric,timestamptz,timestamptz,boolean)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.global_edit_core(uuid,text,text,text,numeric,timestamptz,timestamptz,boolean)
 TO authenticated;

CREATE OR REPLACE FUNCTION public.league_v21_admin_edit_global_challenge(
 p_challenge uuid,
 p_title text,
 p_description text,
 p_metric text,
 p_target numeric,
 p_starts timestamptz,
 p_ends timestamptz,
 p_update_rules boolean
)
RETURNS jsonb
LANGUAGE sql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $func$
 SELECT league_v21_private.global_edit_core(
  p_challenge,p_title,p_description,p_metric,p_target,p_starts,p_ends,p_update_rules
 )
$func$;

REVOKE ALL ON FUNCTION public.league_v21_admin_edit_global_challenge(uuid,text,text,text,numeric,timestamptz,timestamptz,boolean)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.league_v21_admin_edit_global_challenge(uuid,text,text,text,numeric,timestamptz,timestamptz,boolean)
 TO authenticated;

COMMIT;
