-- Rücknahme von 20261029230000_club_types_selfservice.sql: Vereinstrainings wieder nur per Gym-Check-in (sobald gym_training an ist).
-- Stellt training_insert_guard wörtlich wieder her und entfernt den Schalter club_checkin_only. Ändert keine Trainings.
BEGIN;
CREATE OR REPLACE FUNCTION league_private.training_insert_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE uid uuid := auth.uid(); me public.profiles; tname text;
BEGIN
 IF uid IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO me FROM public.profiles p WHERE p.auth_user_id=uid LIMIT 1;
 IF me.id IS NOT NULL AND me.role IN ('admin','coach') AND me.is_active THEN RETURN NEW; END IF;
 NEW.club_tier := NULL;
 NEW.recorded_by := NULL;
 SELECT t.name INTO tname FROM public.training_types t WHERE t.id=NEW.training_type_id AND t.club_only;
 IF tname IS NOT NULL AND league_private.flag_on('gym_training') THEN
  RAISE EXCEPTION '«%» ist ein Vereinstraining und wird im Gym per Check-in erfasst. Selbst eintragen kannst du Heimtraining.', tname
   USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.training_insert_guard() FROM PUBLIC, anon, authenticated;
DELETE FROM public.league_feature_flags WHERE feature_key='club_checkin_only';
NOTIFY pgrst, 'reload schema';
COMMIT;
