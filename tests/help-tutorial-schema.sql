\set ON_ERROR_STOP on
-- Disposable-database test for 20261029110000_help_tutorial.sql (Etappe 7c) inkl. Rollback und erneutem Anwenden.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $fn$ SELECT nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $fn$;
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
CREATE SCHEMA league_private;
CREATE FUNCTION league_private.existing_helper() RETURNS integer LANGUAGE sql AS $fn$ SELECT 1 $fn$;
GRANT USAGE ON SCHEMA league_private TO authenticated;
GRANT EXECUTE ON FUNCTION league_private.existing_helper() TO authenticated;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, auth_user_id uuid UNIQUE, display_name text NOT NULL, role text NOT NULL DEFAULT 'boxer',
 is_active boolean NOT NULL DEFAULT true, is_listed boolean NOT NULL DEFAULT true, archived_at timestamptz);
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY, display_name text, is_enabled boolean NOT NULL DEFAULT false);
GRANT SELECT ON public.profiles, public.league_feature_flags TO authenticated, anon;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_listed,archived_at,is_active) VALUES
 ('00000000-0000-0000-0000-00000000000a','10000000-0000-0000-0000-00000000000a','Owner','admin',true,NULL,true),
 ('00000000-0000-0000-0000-00000000000c','10000000-0000-0000-0000-00000000000c','Marco','coach',true,NULL,true),
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Anna','boxer',true,NULL,true),
 ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Ben','boxer',false,NULL,true),
 ('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','Alt','boxer',true,now(),true);

\ir ../supabase/migrations/20261028180000_coach_ratings_style_test.sql
\ir ../supabase/production-prep/preflight_20261029110000_help_tutorial.sql
\ir ../supabase/migrations/20261029110000_help_tutorial.sql
\ir ../supabase/migrations/20261029110000_help_tutorial.sql
CREATE FUNCTION pg_temp.act(p uuid) RETURNS void LANGUAGE plpgsql AS $fn$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF p IS NULL THEN PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('role','anon',true);
 ELSE PERFORM set_config('request.jwt.claim.sub',p::text,true); PERFORM set_config('role','authenticated',true); END IF;
END $fn$;
GRANT EXECUTE ON FUNCTION pg_temp.act(uuid) TO authenticated, anon;
DO $t$ DECLARE r jsonb; id1 bigint;
 owner uuid := '10000000-0000-0000-0000-00000000000a'; coach uuid := '10000000-0000-0000-0000-00000000000c';
 anna uuid := '10000000-0000-0000-0000-000000000001'; ben uuid := '10000000-0000-0000-0000-000000000002';
BEGIN
 IF (SELECT count(*) FROM public.faq_entries)<>14 THEN RAISE EXCEPTION 'seed twice or missing'; END IF;
 IF has_table_privilege('anon','public.faq_entries','SELECT') OR has_table_privilege('authenticated','public.profile_onboarding','INSERT') THEN RAISE EXCEPTION 'table rights'; END IF;
 -- Gast liest FAQ, darf nicht pflegen / keine Tour
 PERFORM pg_temp.act(NULL);
 r := public.get_faq();
 IF jsonb_array_length(r->'items')<>14 OR (r->>'can_edit')::boolean THEN RAISE EXCEPTION 'guest faq %', r; END IF;
 BEGIN PERFORM public.admin_save_faq(NULL,'start','Neue Frage?','Antwort hier.'); RAISE EXCEPTION 'anon saves'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.mark_tour_seen(1); RAISE EXCEPTION 'anon tour'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Tour: Flag aus → Boxer nein, Admin ja
 PERFORM pg_temp.act(anna);
 IF (public.get_my_onboarding()->>'enabled')::boolean THEN RAISE EXCEPTION 'tour while flag off'; END IF;
 BEGIN PERFORM public.admin_save_faq(NULL,'start','Neue Frage?','Antwort hier.'); RAISE EXCEPTION 'boxer saves'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_save_faq(NULL,'start','Neue Frage?','Antwort hier.'); RAISE EXCEPTION 'coach saves'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 r := public.get_my_onboarding();
 IF NOT (r->>'enabled')::boolean OR (r->>'tour_version')::int<>0 OR r->>'role'<>'admin' THEN RAISE EXCEPTION 'admin preview %', r; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='tutorial';
 PERFORM pg_temp.act(anna);
 r := public.get_my_onboarding();
 IF NOT (r->>'enabled')::boolean OR (r->>'tour_version')::int<>0 THEN RAISE EXCEPTION 'anna tour %', r; END IF;
 BEGIN PERFORM public.mark_tour_seen(0); RAISE EXCEPTION 'version 0'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 IF (public.mark_tour_seen(2)->>'tour_version')::int<>2 OR (public.mark_tour_seen(1)->>'tour_version')::int<>2 THEN RAISE EXCEPTION 'version never goes back'; END IF;
 IF (public.get_my_onboarding()->>'tour_version')::int<>2 THEN RAISE EXCEPTION 'stored'; END IF;
 PERFORM pg_temp.act(ben);
 IF (public.get_my_onboarding()->>'tour_version')::int<>0 THEN RAISE EXCEPTION 'per person'; END IF;
 -- Admin pflegt: neu, ändern, ausblenden (Entwurf nur für Admin sichtbar)
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.admin_save_faq(NULL,'quatsch','Neue Frage?','Antwort hier.'); RAISE EXCEPTION 'category'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_save_faq(NULL,'start','Kurz','Antwort hier.'); RAISE EXCEPTION 'short q'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.admin_save_faq(NULL,'start','  Gibt es eine App?  ','Die Website funktioniert wie eine App.',5,false); id1 := (r->>'id')::bigint;
 IF r->>'question'<>'Gibt es eine App?' OR (r->>'is_published')::boolean THEN RAISE EXCEPTION 'save %', r; END IF;
 r := public.get_faq();
 IF jsonb_array_length(r->'items')<>15 OR NOT (r->>'can_edit')::boolean OR r->'items'->0->>'question'<>'Gibt es eine App?' THEN RAISE EXCEPTION 'admin sees draft first %', r; END IF;
 PERFORM pg_temp.act(anna);
 IF jsonb_array_length(public.get_faq()->'items')<>14 THEN RAISE EXCEPTION 'draft hidden'; END IF;
 PERFORM pg_temp.act(owner);
 PERFORM public.admin_save_faq(id1,'start','Gibt es eine App?','Ja: Website zum Startbildschirm hinzufügen.',5,true);
 BEGIN PERFORM public.admin_save_faq(999999,'start','Gibt es eine App?','Antwort hier.'); RAISE EXCEPTION 'missing id'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.act(NULL);
 IF jsonb_array_length(public.get_faq()->'items')<>15 THEN RAISE EXCEPTION 'published visible to guest'; END IF;
 PERFORM set_config('role','postgres',true);
 RAISE NOTICE 'PASS: Etappe 7c – FAQ (14 Entwürfe, Gäste lesen, nur Admin pflegt, Entwürfe nur für Admin), Tour pro Person und Version (Flag, Admin-Vorschau, nie zurück)';
END $t$;
\ir ../supabase/production-prep/postflight_20261029110000_help_tutorial.sql
\ir ../supabase/production-prep/rollback_20261029110000_help_tutorial.sql
DO $r$ BEGIN
 IF to_regprocedure('public.get_faq()') IS NOT NULL OR (SELECT count(*) FROM public.faq_entries)<>15 OR (SELECT count(*) FROM public.profile_onboarding)<>1 THEN RAISE EXCEPTION 'rollback'; END IF;
 RAISE NOTICE 'PASS: Rollback 7c entfernt RPCs, FAQ und Tour-Stand bleiben';
END $r$;
\ir ../supabase/migrations/20261029110000_help_tutorial.sql
DO $a$ BEGIN IF to_regprocedure('public.get_faq()') IS NULL OR (SELECT count(*) FROM public.faq_entries)<>15 THEN RAISE EXCEPTION 'reapply'; END IF; RAISE NOTICE 'PASS: Migration 7c nach Rollback erneut anwendbar (Startinhalt nicht doppelt)'; END $a$;
