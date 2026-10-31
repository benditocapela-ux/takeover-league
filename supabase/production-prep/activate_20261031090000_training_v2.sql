-- AKTIVIERUNG Training 2.0 (nur nach ausdrücklicher Freigabe des Owners). Einmalig ausführen.
-- 1. Stundenplan: Pflichttrainings Montag, Mittwoch und Samstag = «Reguläres Boxtraining» (Owner-Entscheid 31.10.2026).
--    Die bisherigen Einträge werden in league_private.training_v2_schedule_backup gesichert. Ergänzungseinheiten (Di/Do) bleiben.
--    Bereits geöffnete oder bestätigte Gym-Einheiten behalten ihre Trainingsart und Stufe (gym_sessions speichert beides selbst).
-- 2. Schalter training_v2 einschalten: Boxer wählen Trainingsort und Einheit, Trainer stufen beim Bestätigen ein.
-- Ändert KEINE bestehenden Trainings, Punkte, EXP oder Coins. Rücknahme: deactivate_20261031090000_training_v2.sql
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.staff_review_training(uuid,text,text,bigint,date,integer,text,boolean)') IS NULL THEN
  RAISE EXCEPTION 'Zuerst die Migration 20261031090000_training_v2_classification.sql anwenden';
 END IF;
 IF EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='training_v2' AND is_enabled) THEN RAISE EXCEPTION 'Bereits aktiviert'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS league_private.training_v2_schedule_backup AS SELECT * FROM public.club_schedule WITH NO DATA;
REVOKE ALL ON league_private.training_v2_schedule_backup FROM PUBLIC, anon, authenticated;
TRUNCATE league_private.training_v2_schedule_backup;
INSERT INTO league_private.training_v2_schedule_backup SELECT * FROM public.club_schedule;
-- Pflichttage Mo/Mi/Sa: vorhandene Einheit umstellen, fehlende ergänzen
UPDATE public.club_schedule x SET training_type_id=t.id, tier='pflicht', label='Reguläres Boxtraining', is_active=true, updated_at=now()
FROM public.training_types t
WHERE t.name='Reguläres Boxtraining' AND x.dow IN (1,3,6) AND x.tier='pflicht';
INSERT INTO public.club_schedule(dow,training_type_id,tier,label,duration_minutes,sort_order)
SELECT d, t.id, 'pflicht', 'Reguläres Boxtraining', 90, d FROM public.training_types t, unnest(ARRAY[1,3,6]) d
WHERE t.name='Reguläres Boxtraining' AND NOT EXISTS (SELECT 1 FROM public.club_schedule x WHERE x.dow=d AND x.tier='pflicht' AND x.is_active);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='training_v2';
SELECT x.dow, x.label, x.tier FROM public.club_schedule x WHERE x.is_active ORDER BY x.dow, x.sort_order;
COMMIT;
