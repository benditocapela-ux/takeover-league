-- Etappe 17a (29.10.2026, Owner-Auftrag): Fürs Erste kann jede Trainingsart wieder selbst eingetragen werden.
-- * Neuer Schalter club_checkin_only («Vereinstrainings nur per Gym-Check-in»), startet AUS.
-- * Die Sperre beim Selbst-Eintragen von Vereinstrainings (club_only) greift nur noch, wenn gym_training UND club_checkin_only an sind.
--   Gym-Check-in, Stufen und Wertung bleiben unverändert; die Markierung club_only der Trainingsarten bleibt gespeichert.
-- Keine Trainings, Punkte oder EXP werden geändert.

BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.training_insert_guard()') IS NULL
    OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='training_types' AND column_name='club_only') THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Vereinsstundenplan (20261028230000)';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('club_checkin_only','Vereinstrainings nur per Gym-Check-in',false)
ON CONFLICT (feature_key) DO NOTHING;

-- Einreichen: wie 20261028230000; Vereinsarten nur gesperrt, wenn zusätzlich club_checkin_only an ist.
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
 IF tname IS NOT NULL AND league_private.flag_on('gym_training') AND league_private.flag_on('club_checkin_only') THEN
  RAISE EXCEPTION '«%» ist ein Vereinstraining und wird im Gym per Check-in erfasst. Selbst eintragen kannst du Heimtraining.', tname
   USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.training_insert_guard() FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
