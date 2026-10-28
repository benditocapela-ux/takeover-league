\set ON_ERROR_STOP on
-- Disposable-database test for 20261029100000_feedback_portal.sql (Etappe 7b) inkl. Rollback und erneutem Anwenden.
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
-- Benachrichtigungen wie Produktion (Typen inkl. general)
CREATE TABLE public.boxer_notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid NOT NULL REFERENCES public.profiles(id),
 notification_type text NOT NULL CHECK (notification_type = ANY (ARRAY['training_approved','training_rejected','coach_feedback','coach_goal','league_challenge','boxer_duel','achievement','season','general','level_up'])),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 160), message text NOT NULL CHECK (char_length(message)<=2000),
 target_path text CHECK (target_path IS NULL OR (char_length(target_path)<=300 AND target_path LIKE '/%' AND target_path NOT LIKE '//%')),
 created_at timestamptz NOT NULL DEFAULT now(), read_at timestamptz);
-- Storage wie Supabase (vereinfacht)
CREATE SCHEMA storage;
GRANT USAGE ON SCHEMA storage TO authenticated, anon;
CREATE TABLE storage.buckets(id text PRIMARY KEY, name text NOT NULL, public boolean DEFAULT false, file_size_limit bigint, allowed_mime_types text[]);
CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text REFERENCES storage.buckets(id), name text, owner uuid, created_at timestamptz DEFAULT now(), UNIQUE(bucket_id,name));
CREATE FUNCTION storage.foldername(name text) RETURNS text[] LANGUAGE sql IMMUTABLE AS $fn$ SELECT (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1] $fn$;
GRANT EXECUTE ON FUNCTION storage.foldername(text) TO authenticated, anon;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;
INSERT INTO storage.buckets(id,name,public) VALUES ('boxer-avatars','boxer-avatars',true);
CREATE POLICY "Boxer upload own avatar" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='boxer-avatars');

\ir ../supabase/production-prep/preflight_20261029100000_feedback_portal.sql
\ir ../supabase/migrations/20261029100000_feedback_portal.sql
\ir ../supabase/migrations/20261029100000_feedback_portal.sql

CREATE FUNCTION pg_temp.act(p uuid) RETURNS void LANGUAGE plpgsql AS $fn$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF p IS NULL THEN PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('role','anon',true);
 ELSE PERFORM set_config('request.jwt.claim.sub',p::text,true); PERFORM set_config('role','authenticated',true); END IF;
END $fn$;
GRANT EXECUTE ON FUNCTION pg_temp.act(uuid) TO authenticated, anon;

DO $t$ DECLARE r jsonb; n integer; f1 uuid; f2 uuid;
 owner uuid := '10000000-0000-0000-0000-00000000000a'; coach uuid := '10000000-0000-0000-0000-00000000000c';
 anna uuid := '10000000-0000-0000-0000-000000000001'; ben uuid := '10000000-0000-0000-0000-000000000002';
 annaP uuid := '00000000-0000-0000-0000-000000000001';
 shot1 text := '10000000-0000-0000-0000-000000000001/aaaaaaaa1111.png'; shot2 text := '10000000-0000-0000-0000-000000000001/bbbbbbbb2222.jpg';
BEGIN
 -- Rechte, Flag aus
 IF has_table_privilege('authenticated','public.app_feedback','SELECT') OR has_function_privilege('anon','public.submit_app_feedback(text,text,text,text,text,text[])','EXECUTE')
  OR has_function_privilege('authenticated','league_private.app_feedback_json(public.app_feedback,boolean)','EXECUTE') THEN RAISE EXCEPTION 'rights'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='app_feedback' AND NOT is_enabled) THEN RAISE EXCEPTION 'flag'; END IF;
 IF (SELECT count(*) FROM storage.buckets)<>2 OR (SELECT public FROM storage.buckets WHERE id='feedback-shots') THEN RAISE EXCEPTION 'bucket'; END IF;
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.submit_app_feedback('bug','Knopf geht nicht','Speichern reagiert nicht'); RAISE EXCEPTION 'flag off submit'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF (public.my_app_feedback()->>'enabled')::boolean THEN RAISE EXCEPTION 'enabled while off'; END IF;
 -- Admin kann vorab testen
 PERFORM pg_temp.act(owner);
 r := public.submit_app_feedback('idea','Admin-Test','Vorschau',NULL,NULL,'{}');
 IF r->>'status'<>'open' THEN RAISE EXCEPTION 'admin preview %', r; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='app_feedback';

 -- Screenshots: nur in den eigenen Ordner, lesen nur eigen/Admin
 PERFORM pg_temp.act(anna);
 INSERT INTO storage.objects(bucket_id,name,owner) VALUES ('feedback-shots',shot1,anna),('feedback-shots',shot2,anna);
 BEGIN INSERT INTO storage.objects(bucket_id,name) VALUES ('feedback-shots','10000000-0000-0000-0000-000000000002/cccccccc3333.png'); RAISE EXCEPTION 'foreign folder upload';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF (SELECT count(*) FROM storage.objects WHERE bucket_id='feedback-shots')<>2 THEN RAISE EXCEPTION 'anna reads own'; END IF;
 PERFORM pg_temp.act(ben);
 IF EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id='feedback-shots') THEN RAISE EXCEPTION 'ben reads anna shots'; END IF;
 BEGIN PERFORM public.submit_app_feedback('bug','Fremdes Bild','x',NULL,NULL,ARRAY[shot1]); RAISE EXCEPTION 'foreign attachment'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.act(coach);
 IF EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id='feedback-shots') THEN RAISE EXCEPTION 'coach reads shots'; END IF;
 PERFORM pg_temp.act(owner);
 IF (SELECT count(*) FROM storage.objects WHERE bucket_id='feedback-shots')<>2 THEN RAISE EXCEPTION 'admin reads shots'; END IF;

 -- Melden: Prüfungen
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.submit_app_feedback('spam','Titel','x'); RAISE EXCEPTION 'kind'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_app_feedback('bug','ab','x'); RAISE EXCEPTION 'short title'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_app_feedback('bug','Titel','  '); RAISE EXCEPTION 'empty message'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_app_feedback('bug','Titel','x',NULL,NULL,ARRAY[shot1,shot2,shot1,shot2]); RAISE EXCEPTION '4 images'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_app_feedback('bug','Titel','x',NULL,NULL,ARRAY['10000000-0000-0000-0000-000000000001/zzzzzzzz9999.png']); RAISE EXCEPTION 'missing object'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_app_feedback('bug','Titel','x',NULL,NULL,ARRAY['10000000-0000-0000-0000-000000000001/../x.png']); RAISE EXCEPTION 'path trick'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.submit_app_feedback('bug','  Speichern hängt  ','Beim Speichern dreht es endlos.','/boxer.html','iPhone · Safari 18',ARRAY[shot1,shot2,shot1]);
 f1 := (r->>'id')::uuid;
 IF r->>'title'<>'Speichern hängt' OR jsonb_array_length(r->'attachments')<>2 OR r ? 'device' OR r ? 'author' THEN RAISE EXCEPTION 'submit %', r; END IF;
 BEGIN PERFORM public.submit_app_feedback('bug','Nochmal','x',NULL,NULL,ARRAY[shot1]); RAISE EXCEPTION 'reuse image'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.submit_app_feedback('idea','Dunkler Kalender','Bitte den Kalender dunkler.');f2 := (r->>'id')::uuid;
 r := public.my_app_feedback();
 IF jsonb_array_length(r->'items')<>2 OR NOT (r->>'enabled')::boolean OR (r->>'is_admin')::boolean THEN RAISE EXCEPTION 'mine %', r; END IF;
 BEGIN PERFORM public.admin_list_app_feedback(); RAISE EXCEPTION 'boxer lists'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_update_app_feedback(f1,'done'); RAISE EXCEPTION 'boxer updates'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(ben);
 IF jsonb_array_length(public.my_app_feedback()->'items')<>0 THEN RAISE EXCEPTION 'ben sees anna'; END IF;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_list_app_feedback(); RAISE EXCEPTION 'coach lists'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- Admin: Eingang, Status, Antwort → Benachrichtigung
 PERFORM pg_temp.act(owner);
 r := public.admin_list_app_feedback('open');
 IF jsonb_array_length(r->'items')<>3 OR (r->'counts'->>'open')::int<>3 OR (SELECT x->>'author' FROM jsonb_array_elements(r->'items') x WHERE x->>'id'=f1::text)<>'Anna'
    OR (SELECT x->>'device' FROM jsonb_array_elements(r->'items') x WHERE x->>'id'=f1::text)<>'iPhone · Safari 18' THEN RAISE EXCEPTION 'admin list %', r; END IF;
 BEGIN PERFORM public.admin_update_app_feedback(f1); RAISE EXCEPTION 'nothing'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_app_feedback(f1,'gelesen'); RAISE EXCEPTION 'bad status'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.admin_update_app_feedback(f1,'in_progress');
 r := public.admin_update_app_feedback(f1,'done','Behoben, danke! Bitte neu laden.');
 IF r->>'status'<>'done' OR r->>'reply'<>'Behoben, danke! Bitte neu laden.' THEN RAISE EXCEPTION 'update %', r; END IF;
 r := public.admin_update_app_feedback(f1,'done','Behoben, danke! Bitte neu laden.');
 PERFORM set_config('role','postgres',true);
 SELECT count(*) INTO n FROM public.boxer_notifications WHERE recipient_id=annaP AND notification_type='general' AND target_path='/feedback.html';
 IF n<>2 THEN RAISE EXCEPTION 'notifications % (expected 2: in Arbeit, Antwort; unchanged repeat sends none)', n; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=annaP AND message='Antwort: Behoben, danke! Bitte neu laden.' AND title LIKE 'Feedback «Speichern hängt»: erledigt') THEN RAISE EXCEPTION 'reply notification'; END IF;
 PERFORM pg_temp.act(anna);
 IF (SELECT x->>'reply' FROM jsonb_array_elements(public.my_app_feedback()->'items') x WHERE x->>'id'=f1::text)<>'Behoben, danke! Bitte neu laden.' THEN RAISE EXCEPTION 'anna sees reply'; END IF;
 -- Tageslimit 10
 FOR n IN 1..8 LOOP PERFORM public.submit_app_feedback('other','Meldung '||n,'x'); END LOOP;
 BEGIN PERFORM public.submit_app_feedback('other','Zu viel','x'); RAISE EXCEPTION 'limit'; EXCEPTION WHEN program_limit_exceeded THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 RAISE NOTICE 'PASS: Etappe 7b Feedback-Portal – Flag (Admin-Vorschau), Screenshots nur eigener Ordner und Admin, Prüfungen (Art, Titel, Bilder max. 3, Pfade, Wiederverwendung), nur Admin sieht Eingang/Gerät, Status und Antwort mit Benachrichtigung, Tageslimit 10';
END $t$;

\ir ../supabase/production-prep/postflight_20261029100000_feedback_portal.sql
\ir ../supabase/production-prep/rollback_20261029100000_feedback_portal.sql
DO $r$ BEGIN
 IF to_regprocedure('public.submit_app_feedback(text,text,text,text,text,text[])') IS NOT NULL OR EXISTS (SELECT 1 FROM pg_policies WHERE policyname LIKE 'feedback_shots%') THEN RAISE EXCEPTION 'rollback left objects'; END IF;
 IF (SELECT count(*) FROM public.app_feedback)<>11 OR (SELECT count(*) FROM storage.objects)<>2 OR NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='Boxer upload own avatar') THEN RAISE EXCEPTION 'rollback data/avatar policy'; END IF;
 RAISE NOTICE 'PASS: Rollback 7b entfernt RPCs und Speicher-Regeln, Meldungen, Bilder und Avatar-Regel bleiben';
END $r$;
\ir ../supabase/migrations/20261029100000_feedback_portal.sql
DO $a$ BEGIN IF to_regprocedure('public.my_app_feedback()') IS NULL THEN RAISE EXCEPTION 'reapply'; END IF; RAISE NOTICE 'PASS: Migration 7b nach Rollback erneut anwendbar'; END $a$;
