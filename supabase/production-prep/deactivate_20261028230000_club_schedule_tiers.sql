-- RÜCKNAHME der Aktivierung Etappe 6a: Punkte, EXP und Einstufungen der umgewerteten Trainings aus training_audit wiederherstellen,
-- Punktwerte der Trainingsarten zurücksetzen (50/40/35/30/40), «Technisches Sparring» deaktivieren (falls unbenutzt),
-- Flags gym_training und weekly_quests ausschalten. Jede Rücknahme wird ebenfalls in training_audit festgehalten.
BEGIN;
SELECT league_private.deactivate_club_tiers((SELECT id FROM public.profiles WHERE role='admin' AND is_active AND archived_at IS NULL ORDER BY id LIMIT 1)) AS ergebnis;
UPDATE public.league_feature_flags SET is_enabled=false, updated_at=now() WHERE feature_key IN ('gym_training','weekly_quests');
COMMIT;
