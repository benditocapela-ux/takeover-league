-- Allow pending duel invitations to be withdrawn without touching scoring or settlement.
-- Production use requires the regular migration path and separate explicit FREIGEBEN.
BEGIN;

CREATE OR REPLACE FUNCTION public.duel_v2_withdraw_invite(p_duel_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  actor public.profiles%ROWTYPE;
  duel public.league_duels%ROWTYPE;
  v_now timestamptz;
BEGIN
  SELECT * INTO actor
  FROM public.profiles
  WHERE auth_user_id = (SELECT auth.uid())
    AND is_active IS TRUE
    AND role IN ('boxer','coach','admin');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Aktives Boxer-, Trainer- oder Adminprofil erforderlich'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.league_feature_flags
    WHERE feature_key = 'duels' AND is_enabled IS TRUE
  ) THEN
    RAISE EXCEPTION 'Duelle sind deaktiviert' USING ERRCODE = '42501';
  END IF;

  -- Match duel_v2_respond lock order: participant profiles first, then duel row.
  SELECT * INTO duel FROM public.league_duels WHERE id = p_duel_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Duell-Einladung nicht gefunden' USING ERRCODE = 'P0002';
  END IF;

  PERFORM 1 FROM public.profiles
  WHERE id IN (duel.challenger_id,duel.opponent_id)
  ORDER BY id FOR UPDATE;

  SELECT * INTO duel FROM public.league_duels WHERE id = p_duel_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Duell-Einladung nicht gefunden' USING ERRCODE = 'P0002';
  END IF;

  v_now := pg_catalog.clock_timestamp();

  IF actor.role = 'boxer' AND (
    duel.challenger_id <> actor.id
    OR duel.created_by <> actor.id
    OR duel.initiated_by_coach IS TRUE
  ) THEN
    RAISE EXCEPTION 'Boxer dürfen nur ihre eigene Einladung zurückziehen'
      USING ERRCODE = '42501';
  END IF;

  IF duel.status <> 'pending' THEN
    RAISE EXCEPTION 'Nur offene Einladungen können zurückgezogen werden'
      USING ERRCODE = '22023';
  END IF;

  IF duel.expires_at <= v_now THEN
    UPDATE public.league_duels
    SET status = 'expired', updated_at = v_now
    WHERE id = duel.id;
    INSERT INTO public.league_duel_events(duel_id,boxer_id,event_type)
    VALUES (duel.id,actor.id,'expired');
    RETURN 'expired';
  END IF;

  UPDATE public.league_duels
  SET status = 'cancelled', updated_at = v_now
  WHERE id = duel.id;

  INSERT INTO public.league_duel_events(duel_id,boxer_id,event_type)
  VALUES (duel.id,actor.id,'cancelled');

  RETURN 'cancelled';
END
$function$;

REVOKE ALL ON FUNCTION public.duel_v2_withdraw_invite(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v2_withdraw_invite(uuid)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
