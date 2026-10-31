-- RÜCKNAHME der Aktivierung Training 2.0: Schalter aus, Stundenplan aus der Sicherung wiederherstellen.
-- Bereits bestätigte und eingestufte Trainings bleiben unverändert (sie sind gültig gebucht und im Audit protokolliert).
BEGIN;
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='training_v2';
DO $$ BEGIN
 IF to_regclass('league_private.training_v2_schedule_backup') IS NOT NULL AND EXISTS (SELECT 1 FROM league_private.training_v2_schedule_backup) THEN
  UPDATE public.club_schedule x SET dow=b.dow, training_type_id=b.training_type_id, tier=b.tier, label=b.label,
   duration_minutes=b.duration_minutes, is_active=b.is_active, sort_order=b.sort_order, updated_at=now()
  FROM league_private.training_v2_schedule_backup b WHERE b.id=x.id;
  -- bei der Aktivierung ergänzte Einheiten: deaktivieren statt löschen (Gym-Einheiten können darauf verweisen)
  UPDATE public.club_schedule x SET is_active=false, updated_at=now()
  WHERE NOT EXISTS (SELECT 1 FROM league_private.training_v2_schedule_backup b WHERE b.id=x.id);
 END IF;
END $$;
COMMIT;
