\set ON_ERROR_STOP on
-- Disposable-database test for 20261029160000_self_rating.sql (Etappe 10: Selbsteinschätzung alle 14 Tage, Trainer gibt frei) inkl. Rollback.
-- Grundgerüst wie rating-scale-schema.sql: Coach-Bewertung (Etappe 1) und Regler 1–20 (Etappe 7a), Mitteilungen wie Produktion.
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

CREATE TABLE public.point_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid, points integer NOT NULL DEFAULT 0, exp integer NOT NULL DEFAULT 0);
CREATE TABLE public.boxer_notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid NOT NULL REFERENCES public.profiles(id),
 notification_type text NOT NULL CHECK (notification_type = ANY (ARRAY['training_approved','training_rejected','coach_feedback','coach_goal','league_challenge','boxer_duel','achievement','season','general','level_up'])),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 160), message text NOT NULL DEFAULT '' CHECK (char_length(message)<=2000),
 target_path text CHECK (target_path IS NULL OR (char_length(target_path)<=300 AND target_path LIKE '/%' AND target_path NOT LIKE '//%')),
 created_at timestamptz NOT NULL DEFAULT now(), read_at timestamptz CHECK (read_at IS NULL OR read_at>=created_at));
\ir ../supabase/migrations/20261028180000_coach_ratings_style_test.sql
\ir ../supabase/migrations/20261029090000_rating_scale_20.sql
CREATE FUNCTION pg_temp.act(p uuid) RETURNS void LANGUAGE plpgsql AS $fn$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF p IS NULL THEN PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('role','anon',true);
 ELSE PERFORM set_config('request.jwt.claim.sub',p::text,true); PERFORM set_config('role','authenticated',true); END IF;
END $fn$;
CREATE FUNCTION pg_temp.scores(base integer, extra jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $fn$
 SELECT jsonb_object_agg(k,base) || extra FROM unnest(ARRAY['jab','cross','hook','upper','body','combo','guard','block','slip','roll','parry','counter',
  'stance','steps','angles','ring','endur','pace','recov','timing','dist','plan','focus','heart','coach']) k $fn$;
GRANT EXECUTE ON FUNCTION pg_temp.act(uuid), pg_temp.scores(integer,jsonb) TO authenticated, anon;
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_ratings';
-- Bestehende Coach-Bewertung für Anna (10er-Skala, wie in Produktion)
DO $s$ BEGIN
 PERFORM pg_temp.act('10000000-0000-0000-0000-00000000000a');
 PERFORM public.staff_rate_boxer('00000000-0000-0000-0000-000000000001',pg_temp.scores(6),'Start',10);
 PERFORM set_config('role','postgres',true);
 UPDATE public.boxer_ratings SET created_at=now()-interval '40 days';
END $s$;
CREATE TEMP TABLE ref AS SELECT (SELECT count(*) FROM public.boxer_ratings) AS ratings, (SELECT md5(string_agg(scores::text||scale||coalesce(note,''),'|' ORDER BY id)) FROM public.boxer_ratings) AS rsum;
GRANT SELECT ON ref TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261029160000_self_rating.sql
\ir ../supabase/migrations/20261029160000_self_rating.sql
\ir ../supabase/migrations/20261029160000_self_rating.sql
\ir ../supabase/production-prep/postflight_20261029160000_self_rating.sql

DO $t$ DECLARE r jsonb; id1 bigint; id2 bigint; id3 bigint; n integer;
 owner uuid := '10000000-0000-0000-0000-00000000000a'; coach uuid := '10000000-0000-0000-0000-00000000000c';
 anna uuid := '10000000-0000-0000-0000-000000000001'; ben uuid := '10000000-0000-0000-0000-000000000002'; alt uuid := '10000000-0000-0000-0000-000000000003';
 ownerP uuid := '00000000-0000-0000-0000-00000000000a'; coachP uuid := '00000000-0000-0000-0000-00000000000c';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
BEGIN
 -- Migration hat bestehende Bewertungen nicht verändert
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.boxer_ratings)<>(SELECT ratings FROM ref) OR (SELECT md5(string_agg(scores::text||scale||coalesce(note,''),'|' ORDER BY id)) FROM public.boxer_ratings)<>(SELECT rsum FROM ref)
  THEN RAISE EXCEPTION 'existing ratings changed'; END IF;
 IF has_table_privilege('authenticated','public.rating_self_reviews','SELECT') OR has_function_privilege('anon','public.get_my_self_rating()','EXECUTE')
    OR has_function_privilege('authenticated','league_private.self_review_state(uuid)','EXECUTE') THEN RAISE EXCEPTION 'rights'; END IF;

 -- Flag aus: Boxer sieht nichts und kann nicht einreichen
 PERFORM pg_temp.act(anna);
 r := public.get_my_self_rating();
 IF (r->>'enabled')::boolean OR r->>'reason'<>'flag' THEN RAISE EXCEPTION 'flag off %', r; END IF;
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12)); RAISE EXCEPTION 'submit with flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Trainer sehen die (leere) Liste auch bei ausgeschaltetem Flag
 PERFORM pg_temp.act(coach);
 IF jsonb_array_length(public.staff_list_self_ratings())<>0 THEN RAISE EXCEPTION 'list not empty'; END IF;

 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='self_rating';
 -- Nur mit coach_ratings zusammen
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='coach_ratings';
 PERFORM pg_temp.act(anna);
 IF (public.get_my_self_rating()->>'enabled')::boolean THEN RAISE EXCEPTION 'needs coach_ratings'; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_ratings';

 -- Boxer: Stand, ungültige Noten, Einreichen
 PERFORM pg_temp.act(anna);
 r := public.get_my_self_rating();
 IF NOT (r->>'enabled')::boolean OR NOT (r->>'can_submit')::boolean OR r->'pending'<>'null'::jsonb OR (r->>'interval_days')::int<>14 THEN RAISE EXCEPTION 'state %', r; END IF;
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12,'{"jab":21}')); RAISE EXCEPTION '21'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12,'{"jab":0}')); RAISE EXCEPTION '0'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12) - 'jab'); RAISE EXCEPTION 'missing'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12,'{"extra":5}')); RAISE EXCEPTION 'extra'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12),repeat('x',601)); RAISE EXCEPTION 'long note'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.submit_self_rating(pg_temp.scores(12,'{"jab":18}'),'  Jab viel besser  ');
 id1 := (r->>'id')::bigint;
 IF (r->>'notified')::int<>2 OR (r->>'overall')::int<>61 THEN RAISE EXCEPTION 'submit %', r; END IF;
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12)); RAISE EXCEPTION 'second pending'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 r := public.get_my_self_rating();
 IF (r->>'can_submit')::boolean OR (r->'pending'->>'id')::bigint<>id1 OR (r->'pending'->>'overall')::int<>61 THEN RAISE EXCEPTION 'pending state %', r; END IF;
 -- Boxer darf nicht entscheiden und nicht die Liste sehen
 BEGIN PERFORM public.staff_list_self_ratings(); RAISE EXCEPTION 'boxer lists'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_decide_self_rating(id1,'approve'); RAISE EXCEPTION 'boxer decides'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM 1 FROM public.rating_self_reviews; RAISE EXCEPTION 'table readable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Admin reicht nicht selbst ein; Gäste und archivierte Profile auch nicht
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12)); RAISE EXCEPTION 'admin submits'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF public.get_my_self_rating()->>'reason'<>'role' THEN RAISE EXCEPTION 'admin state'; END IF;
 PERFORM pg_temp.act(alt);
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(12)); RAISE EXCEPTION 'archived submits'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(NULL);
 BEGIN PERFORM public.get_my_self_rating(); RAISE EXCEPTION 'anon'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- Mitteilungen an Admin und Trainer, nicht an den Boxer
 PERFORM set_config('role','postgres',true);
 IF (SELECT string_agg(p.display_name,',' ORDER BY p.display_name) FROM public.boxer_notifications b JOIN public.profiles p ON p.id=b.recipient_id
     WHERE b.target_path='/bewertung.html?selbst='||id1 AND b.read_at IS NULL)<>'Marco,Owner' THEN RAISE EXCEPTION 'staff notifications'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE target_path='/bewertung.html?selbst='||id1 AND title='Selbsteinschätzung von Anna'
   AND message='Anna hat sich selbst eingeschätzt (Gesamt 61). Bitte anpassen oder freigeben.') THEN RAISE EXCEPTION 'notification text'; END IF;
 -- Karte bleibt bis zur Entscheidung unverändert
 IF (SELECT count(*) FROM public.boxer_ratings)<>(SELECT ratings FROM ref) THEN RAISE EXCEPTION 'card changed before decision'; END IF;

 -- Trainer: Liste mit aktueller Bewertung zum Vergleich, dann freigeben
 PERFORM pg_temp.act(coach);
 r := public.staff_list_self_ratings();
 IF jsonb_array_length(r)<>1 OR (r->0->>'id')::bigint<>id1 OR r->0->>'display_name'<>'Anna' OR r->0->>'note'<>'Jab viel besser'
    OR (r->0->>'overall')::int<>61 OR (r->0->'current'->>'overall')::int<>60 OR (r->0->'current'->>'scale')::int<>10 THEN RAISE EXCEPTION 'list %', r; END IF;
 BEGIN PERFORM public.staff_decide_self_rating(id1,'maybe'); RAISE EXCEPTION 'unknown decision'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_decide_self_rating(id1,'approve',NULL,'Passt, weiter so');
 IF r->>'status'<>'approved' OR (r->>'previous_overall')::int<>60 OR (r->>'overall')::int<>61 THEN RAISE EXCEPTION 'approve %', r; END IF;
 BEGIN PERFORM public.staff_decide_self_rating(id1,'decline'); RAISE EXCEPTION 'decided twice'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF NOT EXISTS (SELECT 1 FROM public.boxer_ratings b JOIN public.rating_self_reviews s ON s.rating_id=b.id WHERE s.id=id1 AND b.boxer_id=annaP AND b.rated_by=coachP
   AND b.scale=20 AND b.scores=pg_temp.scores(12,'{"jab":18}') AND b.note='Passt, weiter so') THEN RAISE EXCEPTION 'approved rating'; END IF;
 IF EXISTS (SELECT 1 FROM public.boxer_notifications WHERE target_path='/bewertung.html?selbst='||id1 AND read_at IS NULL) THEN RAISE EXCEPTION 'staff notes not cleared'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=annaP AND title='Deine Selbsteinschätzung ist freigegeben'
   AND message='Neue Gesamtwertung: 61. Kommentar von Marco: Passt, weiter so' AND target_path='/bewertung.html') THEN RAISE EXCEPTION 'boxer note'; END IF;
 -- Spielerkarte zeigt jetzt die freigegebene Bewertung
 PERFORM pg_temp.act(anna);
 r := public.get_my_performance();
 IF (r->'rating'->'current'->'summary'->>'overall')::int<>61 OR (r->'rating'->'current'->>'scale')::int<>20 OR r->'rating'->'current'->>'rated_by'<>'Marco' THEN RAISE EXCEPTION 'card %', r->'rating'; END IF;

 -- 14 Tage: direkt danach gesperrt, am 14. Kalendertag wieder frei
 BEGIN PERFORM public.submit_self_rating(pg_temp.scores(13)); RAISE EXCEPTION 'cooldown'; EXCEPTION WHEN object_not_in_prerequisite_state THEN
  IF SQLERRM !~ '^Die nächste Selbsteinschätzung ist ab \d\d\.\d\d\.\d{4} möglich$' THEN RAISE EXCEPTION 'cooldown text %', SQLERRM; END IF; END;
 r := public.get_my_self_rating();
 IF (r->>'can_submit')::boolean OR r->'last'->>'status'<>'approved' OR r->'last'->>'decided_by'<>'Marco' OR (r->>'next_allowed_on')::date<>(now() AT TIME ZONE 'Europe/Zurich')::date+14 THEN RAISE EXCEPTION 'cooldown state %', r; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.rating_self_reviews SET created_at=created_at-interval '13 days', decided_at=decided_at-interval '13 days';
 UPDATE public.boxer_notifications SET created_at=created_at-interval '13 days', read_at=read_at-interval '13 days';
 PERFORM pg_temp.act(anna);
 IF (public.get_my_self_rating()->>'can_submit')::boolean THEN RAISE EXCEPTION 'free after 13 days'; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.rating_self_reviews SET created_at=created_at-interval '1 day', decided_at=decided_at-interval '1 day';
 PERFORM pg_temp.act(anna);
 IF NOT (public.get_my_self_rating()->>'can_submit')::boolean THEN RAISE EXCEPTION 'not free after 14 days'; END IF;

 -- Anpassen: Admin ändert Noten, seine Version zählt
 id2 := (public.submit_self_rating(pg_temp.scores(16))->>'id')::bigint;
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.staff_decide_self_rating(id2,'adjust',pg_temp.scores(14,'{"jab":25}')); RAISE EXCEPTION 'adjust invalid'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_decide_self_rating(id2,'adjust',NULL); RAISE EXCEPTION 'adjust null'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_decide_self_rating(id2,'adjust',pg_temp.scores(14,'{"jab":19}'),NULL);
 IF r->>'status'<>'adjusted' OR (r->>'previous_overall')::int<>61 OR (r->>'overall')::int<>71 THEN RAISE EXCEPTION 'adjust %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF NOT EXISTS (SELECT 1 FROM public.boxer_ratings b JOIN public.rating_self_reviews s ON s.rating_id=b.id WHERE s.id=id2 AND b.rated_by=ownerP AND b.scores=pg_temp.scores(14,'{"jab":19}') AND b.note IS NULL)
  THEN RAISE EXCEPTION 'adjusted rating'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=annaP AND title='Dein Trainer hat deine Selbsteinschätzung angepasst' AND message='Neue Gesamtwertung: 71.') THEN RAISE EXCEPTION 'adjust note'; END IF;
 -- «Anpassen» mit unveränderten Noten zählt als Freigabe
 UPDATE public.rating_self_reviews SET created_at=created_at-interval '14 days', decided_at=decided_at-interval '14 days';
 PERFORM pg_temp.act(anna);
 id3 := (public.submit_self_rating(pg_temp.scores(15))->>'id')::bigint;
 PERFORM pg_temp.act(coach);
 IF public.staff_decide_self_rating(id3,'adjust',pg_temp.scores(15))->>'status'<>'approved' THEN RAISE EXCEPTION 'same scores = approved'; END IF;

 -- Ablehnen: keine neue Bewertung
 PERFORM set_config('role','postgres',true);
 UPDATE public.rating_self_reviews SET created_at=created_at-interval '14 days', decided_at=decided_at-interval '14 days';
 n := (SELECT count(*) FROM public.boxer_ratings);
 PERFORM pg_temp.act(anna);
 id3 := (public.submit_self_rating(pg_temp.scores(20),'Ich bin Elite')->>'id')::bigint;
 PERFORM pg_temp.act(coach);
 r := public.staff_decide_self_rating(id3,'decline',NULL,'Lass uns zuerst sparren');
 IF r->>'status'<>'declined' OR r->'rating_id'<>'null'::jsonb THEN RAISE EXCEPTION 'decline %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.boxer_ratings)<>n THEN RAISE EXCEPTION 'decline created rating'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=annaP AND title='Deine Selbsteinschätzung wurde nicht übernommen'
   AND message='Deine Spielerkarte bleibt, wie sie ist. Kommentar von Marco: Lass uns zuerst sparren') THEN RAISE EXCEPTION 'decline note'; END IF;
 PERFORM pg_temp.act(anna);
 r := public.get_my_self_rating();
 IF r->'last'->>'status'<>'declined' OR r->'last'->>'coach_note'<>'Lass uns zuerst sparren' OR (r->>'can_submit')::boolean THEN RAISE EXCEPTION 'declined state %', r; END IF;

 -- Trainer als Boxer: nur der Admin wird benachrichtigt, eigene Freigabe verboten
 PERFORM pg_temp.act(coach);
 r := public.submit_self_rating(pg_temp.scores(11));
 IF (r->>'notified')::int<>1 THEN RAISE EXCEPTION 'coach self notified %', r; END IF;
 BEGIN PERFORM public.staff_decide_self_rating((r->>'id')::bigint,'approve'); RAISE EXCEPTION 'own approval'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF NOT (public.staff_list_self_ratings()->0->>'is_self')::boolean THEN RAISE EXCEPTION 'is_self'; END IF;
 PERFORM pg_temp.act(owner);
 IF public.staff_decide_self_rating((r->>'id')::bigint,'approve')->>'status'<>'approved' THEN RAISE EXCEPTION 'owner approves coach'; END IF;

 -- Doppelte offene Einreichung auch auf Tabellenebene ausgeschlossen
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.rating_self_reviews(boxer_id,scores) VALUES (benP,pg_temp.scores(10));
 BEGIN INSERT INTO public.rating_self_reviews(boxer_id,scores) VALUES (benP,pg_temp.scores(10)); RAISE EXCEPTION 'two pending'; EXCEPTION WHEN unique_violation THEN NULL; END;
 RAISE NOTICE 'PASS: Selbsteinschätzung – Flag aus gesperrt, Noten streng geprüft, eine offene, Mitteilungen an Trainer, Karte erst nach Freigabe, freigeben/anpassen/ablehnen, 14 Kalendertage, eigene Freigabe verboten, bestehende Bewertungen unverändert';
END $t$;

-- Rücknahme: verweigert mit Einträgen; ohne sauber; danach erneut einspielbar
\set ON_ERROR_STOP off
\ir ../supabase/production-prep/rollback_20261029160000_self_rating.sql
\set ON_ERROR_STOP on
DO $r$ BEGIN
 IF to_regclass('public.rating_self_reviews') IS NULL THEN RAISE EXCEPTION 'rollback ran despite entries'; END IF;
 RAISE NOTICE 'PASS: Rücknahme verweigert bei vorhandenen Selbsteinschätzungen';
END $r$;
CREATE TEMP TABLE keep AS SELECT count(*) AS n FROM public.boxer_ratings;
DELETE FROM public.rating_self_reviews;
\ir ../supabase/production-prep/rollback_20261029160000_self_rating.sql
DO $r$ BEGIN
 IF to_regclass('public.rating_self_reviews') IS NOT NULL OR to_regprocedure('public.submit_self_rating(jsonb,text)') IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='self_rating') THEN RAISE EXCEPTION 'rollback incomplete'; END IF;
 IF (SELECT count(*) FROM public.boxer_ratings)<>(SELECT n FROM keep) THEN RAISE EXCEPTION 'rollback touched ratings'; END IF;
 RAISE NOTICE 'PASS: Rücknahme sauber, freigegebene Bewertungen bleiben';
END $r$;
\ir ../supabase/migrations/20261029160000_self_rating.sql
DO $r$ BEGIN
 IF to_regprocedure('public.staff_decide_self_rating(bigint,text,jsonb,text)') IS NULL THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
