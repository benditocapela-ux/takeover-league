-- Delete only unused coach-challenge drafts. Published/participated challenges are retained as history.
-- Production use requires the regular migration path and separate explicit FREIGEBEN.
BEGIN;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_delete_draft(p_challenge_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  actor public.profiles%ROWTYPE;
  challenge public.league_coach_challenges%ROWTYPE;
BEGIN
  SELECT * INTO actor
  FROM public.profiles
  WHERE auth_user_id = (SELECT auth.uid())
    AND is_active IS TRUE
    AND role IN ('coach','admin');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Nur aktive Trainer oder Admins dürfen Entwürfe löschen'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.league_feature_flags
    WHERE feature_key = 'coach_challenges' AND is_enabled IS TRUE
  ) THEN
    RAISE EXCEPTION 'Coach-Challenges sind deaktiviert'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO challenge
  FROM public.league_coach_challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Challenge nicht gefunden' USING ERRCODE = 'P0002';
  END IF;

  IF actor.role <> 'admin' AND challenge.created_by <> actor.id THEN
    RAISE EXCEPTION 'Nur der erstellende Trainer oder Admin darf diesen Entwurf löschen'
      USING ERRCODE = '42501';
  END IF;

  IF challenge.status <> 'draft' THEN
    RAISE EXCEPTION 'Nur Entwürfe können gelöscht werden; veröffentlichte Challenges bitte abbrechen'
      USING ERRCODE = '22023';
  END IF;

  -- Preserve every challenge that has any participant/history or any EXP-ledger trace.
  IF EXISTS (SELECT 1 FROM public.league_coach_challenge_entries WHERE challenge_id = challenge.id)
     OR EXISTS (SELECT 1 FROM public.league_coach_challenge_reviews WHERE challenge_id = challenge.id)
     OR EXISTS (SELECT 1 FROM public.league_coach_challenge_exp_ledger WHERE challenge_id = challenge.id)
     OR EXISTS (SELECT 1 FROM public.league_coach_challenge_targets WHERE challenge_id = challenge.id)
     OR EXISTS (
       SELECT 1 FROM public.point_transactions
       WHERE category = 'challenge_exp'
         AND description = 'Challenge reward: ' || challenge.id::text
     )
  THEN
    RAISE EXCEPTION 'Challenge hat bereits Verknüpfungen oder Historie und kann nicht gelöscht werden'
      USING ERRCODE = '23503';
  END IF;

  DELETE FROM public.league_coach_challenges WHERE id = challenge.id;
  RETURN 'deleted';
END
$function$;

REVOKE ALL ON FUNCTION public.coach_challenge_v2_delete_draft(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_delete_draft(uuid)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
