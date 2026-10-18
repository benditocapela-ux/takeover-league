-- PREPARED ONLY: introduce separate V2 feature gates without enabling them.
-- Preserve legacy boxer_duels and league_challenges keys.
BEGIN;
DO $$
BEGIN
 IF to_regclass('public.league_feature_flags') IS NULL THEN
  RAISE EXCEPTION 'Feature flags table missing';
 END IF;
END $$;
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES
 ('coach_challenges','Coach Challenges V2',false),
 ('duels','Duels V2',false)
ON CONFLICT(feature_key) DO NOTHING;
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key IN ('coach_challenges','duels') AND is_enabled) THEN
  RAISE EXCEPTION 'V2 feature unexpectedly enabled; manual review required';
 END IF;
END $$;
COMMIT;
