-- EMERGENCY OFF SWITCH. Data preserving and idempotent.
-- Does not undo a completed EXP transaction or restore a missing backup.
BEGIN;
UPDATE public.league_feature_flags
SET is_enabled=false,updated_at=now()
WHERE feature_key IN ('coach_challenges','duels') AND is_enabled IS TRUE;
COMMIT;
