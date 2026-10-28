\set ON_ERROR_STOP on
-- Disposable-database test for 20261029150000_archive_legacy_v2_flags.sql inkl. Schutzabbrüchen und Rücknahme.
-- Grundgerüst (Rollen, auth.uid, profiles, league_feature_flags, Rollen-Helfer) plus Nachbau der alten V2-Strukturen aus der Produktion.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
END $$;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $fn$ SELECT nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $fn$;
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, auth_user_id uuid UNIQUE, display_name text NOT NULL, role text NOT NULL DEFAULT 'boxer',
 is_active boolean NOT NULL DEFAULT true);
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY, display_name text, is_enabled boolean NOT NULL DEFAULT false, updated_at timestamptz DEFAULT now());
GRANT SELECT ON public.league_feature_flags TO anon, authenticated;
CREATE FUNCTION public.is_league_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT EXISTS (SELECT 1 FROM public.profiles WHERE auth_user_id=auth.uid() AND role='admin' AND is_active) $fn$;
CREATE FUNCTION public.is_league_coach() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT EXISTS (SELECT 1 FROM public.profiles WHERE auth_user_id=auth.uid() AND role IN ('admin','coach') AND is_active) $fn$;
-- Neue Strukturen, die unberührt bleiben müssen
CREATE TABLE public.league_duels(id uuid PRIMARY KEY DEFAULT gen_random_uuid());
CREATE TABLE public.league_seasons_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text);
INSERT INTO public.league_seasons_v21(title) VALUES ('Saison 1'),('Saison 2');
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled) VALUES ('duels','Duelle',true),('coach_challenges','Coach-Challenges',true),('boxer_holo','Boxer-Holo',true);
INSERT INTO public.profiles(id,auth_user_id,display_name,role) VALUES
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-00000000aaa1','Admin','admin'),
 ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-00000000bbb1','Anna','boxer');
\ir legacy-v2-fixture.sql

CREATE TEMP TABLE ref AS SELECT
 (SELECT count(*) FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN
   ('boxer_duels','boxer_coach_goals','league_hall_of_fame','league_challenges','league_challenge_participants','boxer_palmares','boxer_public_profile_details','league_seasons','league_season_results')) AS pol,
 (SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND tablename IN
   ('boxer_duels','boxer_coach_goals','league_hall_of_fame','league_challenges','league_challenge_participants','boxer_palmares','boxer_public_profile_details','league_seasons','league_season_results')) AS idx,
 (SELECT md5(string_agg(pg_get_functiondef(p.oid),'' ORDER BY p.proname)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND p.proname ~ '^(boxer_join_league|boxer_respond_duel|coach_add_|coach_award_season|coach_create_|coach_finalize_|coach_set_|get_boxer_duel|get_league_challenge)') AS fdef;
GRANT SELECT ON ref TO PUBLIC;
DO $t$ BEGIN
 IF (SELECT pol FROM ref)<>18 OR (SELECT idx FROM ref)<>24 THEN RAISE EXCEPTION 'fixture wrong: % policies, % indexes', (SELECT pol FROM ref), (SELECT idx FROM ref); END IF;
 RAISE NOTICE 'PASS: Altstruktur wie Produktion (9 Tabellen, 18 Regeln, 24 Indizes, 16 Funktionen, 7 Schalter aus)';
END $t$;

-- Schutz 1: ein alter Schalter ist an -> Abbruch ohne Änderung
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='palmares';
\set ON_ERROR_STOP off
\ir ../supabase/migrations/20261029150000_archive_legacy_v2_flags.sql
\set ON_ERROR_STOP on
DO $t$ BEGIN
 IF to_regclass('public.boxer_duels') IS NULL OR to_regnamespace('legacy_v2_archive') IS NOT NULL
    OR (SELECT count(*) FROM public.league_feature_flags WHERE feature_key IN ('boxer_duels','coach_goals','hall_of_fame','league_challenges','palmares','public_boxer_profiles','seasons'))<>7 THEN
  RAISE EXCEPTION 'migration ran although a legacy flag was on';
 END IF;
 RAISE NOTICE 'PASS: Abbruch, wenn ein alter Schalter an ist';
END $t$;
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='palmares';

-- Schutz 2: eine alte Tabelle hat Zeilen -> Abbruch ohne Änderung
INSERT INTO public.league_seasons(name,starts_on,ends_on) VALUES ('Alt',DATE '2026-01-01',DATE '2026-02-01');
\set ON_ERROR_STOP off
\ir ../supabase/migrations/20261029150000_archive_legacy_v2_flags.sql
\set ON_ERROR_STOP on
DO $t$ BEGIN
 IF to_regclass('public.league_seasons') IS NULL OR to_regnamespace('legacy_v2_archive') IS NOT NULL
    OR NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='seasons') THEN
  RAISE EXCEPTION 'migration ran although a legacy table had rows';
 END IF;
 RAISE NOTICE 'PASS: Abbruch, wenn eine alte Tabelle Zeilen hat';
END $t$;
DELETE FROM public.league_seasons;

-- Schutz 3: eine fremde Tabelle verweist auf eine alte -> Abbruch
CREATE TABLE public.fremd(id uuid PRIMARY KEY, season_id uuid REFERENCES public.league_seasons(id));
\set ON_ERROR_STOP off
\ir ../supabase/migrations/20261029150000_archive_legacy_v2_flags.sql
\set ON_ERROR_STOP on
DO $t$ BEGIN
 IF to_regclass('public.league_seasons') IS NULL OR to_regnamespace('legacy_v2_archive') IS NOT NULL THEN RAISE EXCEPTION 'migration ran despite foreign reference'; END IF;
 RAISE NOTICE 'PASS: Abbruch bei fremden Verweisen';
END $t$;
DROP TABLE public.fremd;

-- Durchlauf, zweimal (wiederholbar)
\ir ../supabase/migrations/20261029150000_archive_legacy_v2_flags.sql
\ir ../supabase/migrations/20261029150000_archive_legacy_v2_flags.sql
DO $t$ DECLARE tname text; BEGIN
 IF EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key IN ('boxer_duels','coach_goals','hall_of_fame','league_challenges','palmares','public_boxer_profiles','seasons')) THEN
  RAISE EXCEPTION 'legacy flags still there';
 END IF;
 IF (SELECT string_agg(feature_key||':'||is_enabled,',' ORDER BY feature_key) FROM public.league_feature_flags)<>'boxer_holo:true,coach_challenges:true,duels:true' THEN
  RAISE EXCEPTION 'other flags changed';
 END IF;
 IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='legacy_v2_archive' AND c.relkind='r')<>9
    OR (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='legacy_v2_archive')<>16 THEN
  RAISE EXCEPTION 'archive incomplete';
 END IF;
 FOREACH tname IN ARRAY ARRAY['boxer_duels','boxer_coach_goals','league_hall_of_fame','league_challenges','league_challenge_participants','boxer_palmares','boxer_public_profile_details','league_seasons','league_season_results'] LOOP
  IF to_regclass('public.'||tname) IS NOT NULL THEN RAISE EXCEPTION 'public.% still there', tname; END IF;
 END LOOP;
 IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND p.proname ~ '^(boxer_join_league|boxer_respond_duel|coach_add_|coach_award_season|coach_create_|coach_finalize_|coach_set_|get_boxer_duel|get_league_challenge)') THEN
  RAISE EXCEPTION 'legacy function left in public';
 END IF;
 IF (SELECT count(*) FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='legacy_v2_archive')<>18
    OR (SELECT count(*) FROM pg_indexes WHERE schemaname='legacy_v2_archive')<>24 THEN
  RAISE EXCEPTION 'policies/indexes did not move';
 END IF;
 IF has_schema_privilege('anon','legacy_v2_archive','USAGE') OR has_schema_privilege('authenticated','legacy_v2_archive','USAGE')
    OR has_schema_privilege('service_role','legacy_v2_archive','USAGE') THEN
  RAISE EXCEPTION 'archive reachable';
 END IF;
 IF to_regclass('public.league_duels') IS NULL OR (SELECT count(*) FROM public.league_seasons_v21)<>2 OR (SELECT count(*) FROM public.profiles)<>2 THEN
  RAISE EXCEPTION 'new structures touched';
 END IF;
 RAISE NOTICE 'PASS: 7 Schalter entfernt, 9 Tabellen mit 18 Regeln und 24 Indizes sowie 16 Funktionen im gesperrten Archiv, andere Schalter und neue Strukturen unverändert, zweiter Lauf ohne Fehler';
END $t$;

-- Kein Zugriff mehr für App-Rollen
SET ROLE authenticated;
DO $t$ BEGIN
 BEGIN PERFORM 1 FROM legacy_v2_archive.boxer_duels; RAISE EXCEPTION 'authenticated reads archive'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM legacy_v2_archive.get_boxer_duel_score(gen_random_uuid()); RAISE EXCEPTION 'authenticated calls archive'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RAISE NOTICE 'PASS: App-Rollen kommen nicht ins Archiv';
END $t$;
RESET ROLE;
SET ROLE service_role;
DO $t$ BEGIN
 BEGIN PERFORM 1 FROM legacy_v2_archive.league_seasons; RAISE EXCEPTION 'service_role reads archive'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RAISE NOTICE 'PASS: auch service_role nicht';
END $t$;
RESET ROLE;

-- Rücknahme holt alles unverändert zurück
\ir ../supabase/production-prep/rollback_20261029150000_archive_legacy_v2_flags.sql
DO $t$ BEGIN
 IF to_regnamespace('legacy_v2_archive') IS NOT NULL THEN RAISE EXCEPTION 'archive left'; END IF;
 IF (SELECT count(*) FROM public.league_feature_flags WHERE NOT is_enabled AND feature_key IN ('boxer_duels','coach_goals','hall_of_fame','league_challenges','palmares','public_boxer_profiles','seasons'))<>7 THEN
  RAISE EXCEPTION 'flags not restored';
 END IF;
 IF (SELECT count(*) FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN
   ('boxer_duels','boxer_coach_goals','league_hall_of_fame','league_challenges','league_challenge_participants','boxer_palmares','boxer_public_profile_details','league_seasons','league_season_results'))<>(SELECT pol FROM ref)
  OR (SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND tablename IN
   ('boxer_duels','boxer_coach_goals','league_hall_of_fame','league_challenges','league_challenge_participants','boxer_palmares','boxer_public_profile_details','league_seasons','league_season_results'))<>(SELECT idx FROM ref)
  OR (SELECT md5(string_agg(pg_get_functiondef(p.oid),'' ORDER BY p.proname)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND p.proname ~ '^(boxer_join_league|boxer_respond_duel|coach_add_|coach_award_season|coach_create_|coach_finalize_|coach_set_|get_boxer_duel|get_league_challenge)')<>(SELECT fdef FROM ref) THEN
  RAISE EXCEPTION 'restore not identical';
 END IF;
 IF NOT has_table_privilege('authenticated','public.league_seasons','SELECT') OR NOT has_table_privilege('authenticated','public.boxer_coach_goals','INSERT')
    OR has_function_privilege('authenticated','public.coach_create_league_season(text,date,date,text)','EXECUTE')
    OR NOT has_function_privilege('service_role','public.coach_create_league_season(text,date,date,text)','EXECUTE') THEN
  RAISE EXCEPTION 'grants not restored';
 END IF;
 RAISE NOTICE 'PASS: Rücknahme stellt Tabellen, Regeln, Indizes, Funktionen, Rechte und Schalter identisch wieder her';
END $t$;

-- Rücknahme ohne Archiv bricht ab; danach erneut einspielbar
\set ON_ERROR_STOP off
\ir ../supabase/production-prep/rollback_20261029150000_archive_legacy_v2_flags.sql
\set ON_ERROR_STOP on
\ir ../supabase/migrations/20261029150000_archive_legacy_v2_flags.sql
DO $t$ BEGIN
 IF to_regclass('legacy_v2_archive.boxer_duels') IS NULL OR EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='seasons') THEN RAISE EXCEPTION 're-apply failed'; END IF;
 RAISE NOTICE 'PASS: Rücknahme ohne Archiv verweigert, erneutes Einspielen klappt';
END $t$;
