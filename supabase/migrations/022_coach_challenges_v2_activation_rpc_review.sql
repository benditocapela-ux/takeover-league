-- REVIEW ONLY. Explicit coach activation starts the clock but never awards EXP.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_activate(p_challenge_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
 v_now timestamptz;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
 AND is_active=true AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Coach authorization required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
 RAISE EXCEPTION 'Coach challenges disabled'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND c.created_by<>actor.id THEN
 RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.status<>'open' THEN RAISE EXCEPTION 'Only open challenges can activate'; END IF;
 IF c.starts_at IS NOT NULL OR c.ends_at IS NOT NULL OR c.settled_at IS NOT NULL THEN
 RAISE EXCEPTION 'Challenge clock already initialized'; END IF;
 IF c.goal_spec IS NULL OR c.goal_spec->>'version'<>'1'
 OR pg_catalog.char_length(pg_catalog.btrim(c.goal_spec->>'goal_text')) NOT BETWEEN 5 AND 1000
 OR c.goal_spec->>'review_mode' NOT IN ('manual','automatic') THEN
 RAISE EXCEPTION 'Valid goal required before activation'; END IF;
 IF c.goal_spec->>'review_mode'='automatic' THEN
 RAISE EXCEPTION 'Automatic goal settlement is not implemented'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND status='joined') THEN
 RAISE EXCEPTION 'At least one participant required'; END IF;
 v_now:=pg_catalog.clock_timestamp();
 UPDATE public.league_coach_challenges SET status='active',
 starts_at=v_now,ends_at=v_now+(duration_days * interval '1 day'),updated_at=v_now
 WHERE id=c.id;
 RETURN 'active';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_activate(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_activate(uuid) TO authenticated;
COMMIT;
