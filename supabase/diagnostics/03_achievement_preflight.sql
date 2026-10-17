-- Takeover League 2.0 / Achievement discovery. READ ONLY.
-- Run in Supabase SQL Editor; share outputs excluding personal identifiers if preferred.
-- 1. Existing achievement definitions (avoid duplicates).
SELECT id, code, title, category, is_active
FROM public.achievement_definitions ORDER BY category, code;

-- 2. Existing awards and source keys (detect previous backfills).
SELECT a.code, COUNT(ba.id) AS awards,
       COUNT(DISTINCT ba.boxer_id) AS distinct_boxers
FROM public.achievement_definitions a
LEFT JOIN public.boxer_achievements ba ON ba.achievement_id = a.id
GROUP BY a.code ORDER BY a.code;

-- 3. Training type names, points and IDs (needed for exact type matching).
SELECT id, name, points, is_active
FROM public.training_types ORDER BY id;

-- 4. Relevant table columns, defaults and nullability.
SELECT table_name, ordinal_position, column_name, data_type,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public'
  AND table_name IN ('achievement_definitions','boxer_achievements',
                     'training_submissions','training_types','point_transactions')
ORDER BY table_name, ordinal_position;

-- 5. Existing constraints / uniqueness.
SELECT con.conrelid::regclass::text AS table_name, con.conname AS constraint_name,
       pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
WHERE con.conrelid IN ('public.achievement_definitions'::regclass,
                      'public.boxer_achievements'::regclass)
ORDER BY table_name, constraint_name;

-- 6. Existing achievement trigger/function logic; review before backfill.
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND (p.proname ILIKE '%achievement%' OR p.proname ILIKE '%bonus%')
ORDER BY p.proname;

-- 7. Training-related approved volume and optional metrics coverage.
SELECT tt.id AS training_type_id, tt.name AS training_type,
       COUNT(*) FILTER (WHERE s.status='approved') AS approved_sessions,
       COALESCE(SUM(s.jogging_km) FILTER (WHERE s.status='approved'),0) AS approved_km,
       COALESCE(SUM(s.technique_minutes) FILTER (WHERE s.status='approved'),0) AS approved_technique_minutes
FROM public.training_types tt
LEFT JOIN public.training_submissions s ON s.training_type_id=tt.id
GROUP BY tt.id,tt.name ORDER BY tt.id;
