-- TEST PROJECT ONLY: cfgdvcccsqwfjajuizsr. NEVER RUN ON PRODUCTION.
-- Schema-only additive bootstrap. Review before execution.
BEGIN;
CREATE TABLE IF NOT EXISTS public.achievement_definitions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 code text NOT NULL UNIQUE CHECK (code ~ '^[a-z][a-z0-9_]{1,63}$'),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 120),
 description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 1000),
 icon_key text,
 category text NOT NULL DEFAULT 'general' CHECK (char_length(category) BETWEEN 1 AND 60),
 is_active boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.achievement_definitions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.achievement_definitions FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.boxer_achievements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 achievement_id uuid NOT NULL REFERENCES public.achievement_definitions(id),
 earned_at timestamptz NOT NULL DEFAULT now(),
 source_key text CHECK (source_key IS NULL OR char_length(source_key) <= 200),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(boxer_id,achievement_id)
);
ALTER TABLE public.boxer_achievements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.boxer_achievements FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.league_feature_flags (
 feature_key text PRIMARY KEY CHECK (feature_key ~ '^[a-z][a-z0-9_]*$'),
 display_name text NOT NULL DEFAULT '',
 is_enabled boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.league_feature_flags ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.league_feature_flags FROM PUBLIC, anon, authenticated;
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('achievements','Achievements',false),('duels','Duels',false),('coach_challenges','Coach challenges',false)
ON CONFLICT (feature_key) DO NOTHING;
COMMIT;
