\set ON_ERROR_STOP on
-- Disposable-database test for 20261028150000_training_types_duration_notes.sql (+ rollback, re-apply).
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA league_v21_private;
CREATE SCHEMA league_private;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, display_name text NOT NULL);
-- Wie in der Produktion: id als GENERATED ALWAYS AS IDENTITY.
CREATE TABLE public.training_types(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name text NOT NULL UNIQUE, points integer NOT NULL CHECK (points>=0), is_active boolean NOT NULL DEFAULT true);
CREATE TABLE public.training_submissions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 training_type_id bigint NOT NULL REFERENCES public.training_types(id), training_date date NOT NULL DEFAULT current_date,
 notes text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'pending', jogging_km numeric, technique_minutes integer);
CREATE TABLE public.training_drafts_v2(boxer_id uuid PRIMARY KEY REFERENCES public.profiles(id), training_type_id bigint REFERENCES public.training_types(id),
 training_date date, notes text, jogging_km numeric, technique_minutes integer, updated_at timestamptz);
-- Bonus-Funktionen wie in der Produktion: erkennen Sparring am Namen (genau ein Vorkommen).
CREATE FUNCTION public.recalculate_boxer_bonuses(p_boxer uuid) RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path=''
AS $fn$ SELECT count(distinct t.name)::integer FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
 WHERE s.boxer_id=p_boxer AND s.status='approved' AND t.name in ('Reguläres Boxtraining','Sparring','Krafttraining','Sprint-Intervalle') $fn$;
CREATE FUNCTION league_private.coach_training_bonus_refresh(p_boxer uuid) RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path=''
AS $fn$ SELECT count(distinct t.name)::integer FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
 WHERE s.boxer_id=p_boxer AND s.status='approved' AND t.name in ('Reguläres Boxtraining','Sparring','Krafttraining','Sprint-Intervalle') $fn$;

INSERT INTO public.training_types OVERRIDING SYSTEM VALUE VALUES (1,'Reguläres Boxtraining',50,true),(2,'Sparring',70,true),(3,'Techniktraining',40,true),
 (4,'Krafttraining',30,true),(5,'Sprint-Intervalle',40,true),(6,'Joggen',20,true);
SELECT setval(pg_get_serial_sequence('public.training_types','id'),6);
INSERT INTO public.profiles VALUES ('00000000-0000-0000-0000-000000000001','Anna');
-- Altbestand ohne Bemerkung und ohne Dauer (muss unverändert bleiben)
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,status) VALUES
 ('a0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',1,'approved'),
 ('a0000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',2,'approved'),
 ('a0000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001',4,'approved'),
 ('a0000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001',5,'approved');
DO $t$ BEGIN IF public.recalculate_boxer_bonuses('00000000-0000-0000-0000-000000000001')<>4 THEN RAISE EXCEPTION 'baseline bonus'; END IF; END $t$;

\ir ../supabase/migrations/20261028150000_training_types_duration_notes.sql

DO $t$ DECLARE n integer; BEGIN
 -- Arten
 IF (SELECT count(*) FROM public.training_types)<>15 THEN RAISE EXCEPTION 'expected 15 types'; END IF;
 IF (SELECT name FROM public.training_types WHERE id=2)<>'Wettkampfsparring' OR (SELECT points FROM public.training_types WHERE id=2)<>70 THEN RAISE EXCEPTION 'rename'; END IF;
 IF EXISTS (SELECT 1 FROM public.training_types WHERE category IS NULL OR sort_order IS NULL) THEN RAISE EXCEPTION 'category missing'; END IF;
 IF (SELECT count(DISTINCT category) FROM public.training_types)<>5 THEN RAISE EXCEPTION 'expected 5 categories'; END IF;
 IF (SELECT points FROM public.training_types WHERE name='Pratzentraining')>=(SELECT points FROM public.training_types WHERE name='Techniktraining') THEN RAISE EXCEPTION 'Technik must beat Pratzen'; END IF;
 IF (SELECT points FROM public.training_types WHERE name='Wettkampf')<>100 THEN RAISE EXCEPTION 'Wettkampf points'; END IF;
 IF (SELECT string_agg(name||'='||points,',' ORDER BY id) FROM public.training_types WHERE id<=6)
    <>'Reguläres Boxtraining=50,Wettkampfsparring=70,Techniktraining=40,Krafttraining=30,Sprint-Intervalle=40,Joggen=20' THEN RAISE EXCEPTION 'existing points changed'; END IF;
 -- Bonus zählt Wettkampfsparring weiter (kein Verlust)
 IF public.recalculate_boxer_bonuses('00000000-0000-0000-0000-000000000001')<>4 OR league_private.coach_training_bonus_refresh('00000000-0000-0000-0000-000000000001')<>4 THEN RAISE EXCEPTION 'bonus lost after rename'; END IF;
 IF NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.recalculate_boxer_bonuses(uuid)'::regprocedure) THEN RAISE EXCEPTION 'security definer lost'; END IF;
 -- Altbestand unverändert
 IF (SELECT count(*) FROM public.training_submissions WHERE notes='' AND duration_minutes IS NULL)<>4 THEN RAISE EXCEPTION 'old rows changed'; END IF;
END $t$;

-- Pflichtangaben für neue Meldungen
DO $t$ BEGIN
 BEGIN INSERT INTO public.training_submissions(boxer_id,training_type_id,duration_minutes) VALUES ('00000000-0000-0000-0000-000000000001',1,60);
  RAISE EXCEPTION 'missing notes accepted'; EXCEPTION WHEN check_violation THEN IF SQLERRM NOT LIKE 'Bitte eine Bemerkung%' THEN RAISE; END IF; END;
 BEGIN INSERT INTO public.training_submissions(boxer_id,training_type_id,notes,duration_minutes) VALUES ('00000000-0000-0000-0000-000000000001',1,'  ab  ',60);
  RAISE EXCEPTION 'short notes accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN INSERT INTO public.training_submissions(boxer_id,training_type_id,notes) VALUES ('00000000-0000-0000-0000-000000000001',1,'Pratzen und Sack');
  RAISE EXCEPTION 'missing duration accepted'; EXCEPTION WHEN check_violation THEN IF SQLERRM NOT LIKE 'Bitte die Trainingsdauer%' THEN RAISE; END IF; END;
 BEGIN INSERT INTO public.training_submissions(boxer_id,training_type_id,notes,duration_minutes) VALUES ('00000000-0000-0000-0000-000000000001',1,'Zu lang',1441);
  RAISE EXCEPTION 'duration > 1440 accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END $t$;
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,notes,duration_minutes) VALUES
 ('b0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',1,'  Gutes Boxtraining  ',90),
 ('b0000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',3,'Jab und Cross',45);
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,notes,duration_minutes)
 SELECT 'b0000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001',id,'Pratzen mit Coach',30 FROM public.training_types WHERE name='Pratzentraining';
DO $t$ BEGIN
 IF (SELECT notes FROM public.training_submissions WHERE id='b0000000-0000-0000-0000-000000000001')<>'Gutes Boxtraining' THEN RAISE EXCEPTION 'notes not trimmed'; END IF;
 IF (SELECT technique_minutes FROM public.training_submissions WHERE id='b0000000-0000-0000-0000-000000000002')<>45 THEN RAISE EXCEPTION 'technique minutes not derived'; END IF;
 IF (SELECT technique_minutes FROM public.training_submissions WHERE id='b0000000-0000-0000-0000-000000000001') IS NOT NULL THEN RAISE EXCEPTION 'technique minutes on boxing'; END IF;
END $t$;
-- Korrektur eines alten Eintrags ohne Bemerkung bleibt möglich (nur INSERT ist geprüft)
UPDATE public.training_submissions SET status='rejected' WHERE id='a0000000-0000-0000-0000-000000000001';
UPDATE public.training_submissions SET status='approved' WHERE id='a0000000-0000-0000-0000-000000000001';

-- Idempotent
\ir ../supabase/migrations/20261028150000_training_types_duration_notes.sql
DO $t$ BEGIN
 IF (SELECT count(*) FROM public.training_types)<>15 THEN RAISE EXCEPTION 'reapply duplicated types'; END IF;
 IF (SELECT count(*) FROM regexp_matches(pg_get_functiondef('public.recalculate_boxer_bonuses(uuid)'::regprocedure),'''Wettkampfsparring''','g'))<>1 THEN RAISE EXCEPTION 'reapply bonus'; END IF;
END $t$;

-- Rollback: Daten bleiben, genutzte neue Art nur deaktiviert
\ir ../supabase/production-prep/rollback_20261028150000_training_types_duration_notes.sql
DO $t$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='league_v21_require_training_details') THEN RAISE EXCEPTION 'rollback left trigger'; END IF;
 IF (SELECT name FROM public.training_types WHERE id=2)<>'Sparring' THEN RAISE EXCEPTION 'rollback rename'; END IF;
 IF (SELECT count(*) FROM public.training_types)<>7 THEN RAISE EXCEPTION 'rollback should keep 6 + used Pratzentraining'; END IF;
 IF (SELECT is_active FROM public.training_types WHERE name='Pratzentraining') THEN RAISE EXCEPTION 'used type must be deactivated'; END IF;
 IF public.recalculate_boxer_bonuses('00000000-0000-0000-0000-000000000001')<>4 THEN RAISE EXCEPTION 'rollback bonus'; END IF;
 IF (SELECT count(*) FROM public.training_submissions)<>7 OR (SELECT duration_minutes FROM public.training_submissions WHERE id='b0000000-0000-0000-0000-000000000001')<>90 THEN RAISE EXCEPTION 'rollback lost data'; END IF;
END $t$;
INSERT INTO public.training_submissions(boxer_id,training_type_id) VALUES ('00000000-0000-0000-0000-000000000001',1);

-- Erneut anwenden nach Rollback
\ir ../supabase/migrations/20261028150000_training_types_duration_notes.sql
DO $t$ BEGIN
 IF (SELECT count(*) FROM public.training_types WHERE is_active)<>15 THEN RAISE EXCEPTION 'reapply after rollback'; END IF;
 IF public.recalculate_boxer_bonuses('00000000-0000-0000-0000-000000000001')<>4 THEN RAISE EXCEPTION 'bonus after reapply'; END IF;
END $t$;
SELECT 'PASS: 15 Trainingsarten in 5 Bereichen, Wettkampfsparring ohne Bonusverlust, Bemerkung und Dauer Pflicht nur für neue Meldungen, idempotent, Rollback behält Daten' AS result;
