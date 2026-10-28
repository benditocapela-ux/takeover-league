-- Etappe 6a (28.10.2026, Owner-Auftrag): Vereins-Stundenplan und Trainingswertung in drei Stufen.
-- Owner-Entscheide:
-- * 5 feste Vereinseinheiten: Mo Technisches Sparring, Di Sandsack, Mi Technik/Pratzen, Do Athletik/Kraft, Sa Technisches Sparring.
--   Mo/Mi/Sa = Pflichttraining, Di/Do = Ergänzungstraining.
-- * Wertung: Pflicht 60 EXP · 15 Coins · 15 Kampfpfad-Punkte, Ergänzung 40 · 12 · 12, Heimtraining nach Trainingsart (15–30) · 10 · 10.
--   Die Stufe gilt für Einheiten im Gym, deren Anwesenheit ein Coach bestätigt (Gym-Check-in), oder die ein Coach einstuft.
--   Höhere Werte einer Trainingsart bleiben (z. B. Wettkampfsparring 70): Wert = max(Stufenwert, Punkte der Trainingsart).
-- * Vereinsarten (Reguläres Boxtraining, Techniktraining, Pratzentraining, Sandsack, Technisches Sparring) gibt es nur noch über
--   das Gym; Boxer reichen nur Heimarten selbst ein (gilt sobald das Flag gym_training an ist).
-- * Coaches/Admin können bestätigte Einheiten nachträglich umstellen (Trainingsart, Stufe); EXP, Punkte, Coins und Kampfpfad
--   folgen automatisch, jede Änderung steht in der Trainings-Änderungshistorie (training_audit).
-- * Solange das Flag gym_training aus ist, wirkt keine Stufe (Bestätigen bucht wie bisher, Einstufen ist gesperrt).
-- * Pflicht-Quest «Alle 3 Pflichttrainings» (80 Coins, keine Zusatz-EXP: Deckel «Moderat» 175 EXP/Woche bleibt) und Pflichtquote
--   nur für die Gruppe Wettkämpfer. Gruppennamen bleiben.
-- * Wochenplan entsteht automatisch aus dem Stundenplan, solange der Coach keinen eigenen Plan veröffentlicht.
-- Diese Migration ändert KEINE bestehenden Trainings, Punkte, EXP oder Coins und keine Punktwerte der Trainingsarten.
-- Umwertung der bestehenden Trainings und Einschalten erfolgen getrennt mit
--   supabase/production-prep/activate_20261028230000_club_schedule_tiers.sql (nur nach ausdrücklicher Freigabe).
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.gym_sessions') IS NULL OR to_regclass('public.quest_definitions') IS NULL
    OR to_regprocedure('league_private.kg_sync(uuid)') IS NULL OR to_regprocedure('league_private.kg_pass_points(uuid,date)') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: zuerst Etappen 2 bis 5 (20261028190000 bis 20261028220000) anwenden';
 END IF;
 IF to_regprocedure('public.admin_edit_training(uuid,uuid,bigint,date,text,text)') IS NULL OR to_regclass('public.training_audit') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: public.admin_edit_training / public.training_audit';
 END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Stufen und Stundenplan
CREATE TABLE IF NOT EXISTS public.club_tiers(
 tier text PRIMARY KEY CHECK (tier IN ('pflicht','ergaenzung')),
 label text NOT NULL CHECK (char_length(label) BETWEEN 3 AND 40),
 exp integer NOT NULL CHECK (exp BETWEEN 0 AND 200),
 coins integer NOT NULL CHECK (coins BETWEEN 0 AND 500),
 pass_points integer NOT NULL CHECK (pass_points BETWEEN 0 AND 100),
 required_groups text[] NOT NULL DEFAULT '{}'
);
INSERT INTO public.club_tiers(tier,label,exp,coins,pass_points,required_groups) VALUES
 ('pflicht','Pflichttraining',60,15,15,'{wettkampf}'),
 ('ergaenzung','Ergänzungstraining',40,12,12,'{}')
ON CONFLICT(tier) DO NOTHING;

ALTER TABLE public.training_types ADD COLUMN IF NOT EXISTS club_only boolean NOT NULL DEFAULT false;
UPDATE public.training_types SET club_only=true
 WHERE name IN ('Reguläres Boxtraining','Techniktraining','Pratzentraining','Sandsack / Rundenarbeit') AND NOT club_only;

-- Neue Trainingsart «Technisches Sparring» (Vereinsart). Bleibt inaktiv bis zur Aktivierung.
DO $types$
DECLARE generated boolean;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.training_types t WHERE t.name='Technisches Sparring') THEN
  generated := (SELECT attidentity IN ('a','d') FROM pg_attribute WHERE attrelid='public.training_types'::regclass AND attname='id');
  IF generated THEN
   INSERT INTO public.training_types(name,points,is_active,category,sort_order,club_only) VALUES ('Technisches Sparring',30,false,'Boxen',105,true);
  ELSE
   INSERT INTO public.training_types(id,name,points,is_active,category,sort_order,club_only)
   VALUES ((SELECT coalesce(max(id),0)+1 FROM public.training_types),'Technisches Sparring',30,false,'Boxen',105,true);
  END IF;
 END IF;
END
$types$;

CREATE TABLE IF NOT EXISTS public.club_schedule(
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 dow smallint NOT NULL CHECK (dow BETWEEN 1 AND 7),
 training_type_id bigint NOT NULL REFERENCES public.training_types(id),
 tier text REFERENCES public.club_tiers(tier),
 label text NOT NULL CHECK (char_length(btrim(label)) BETWEEN 3 AND 60),
 duration_minutes integer NOT NULL DEFAULT 90 CHECK (duration_minutes BETWEEN 15 AND 600),
 is_active boolean NOT NULL DEFAULT true,
 sort_order smallint NOT NULL DEFAULT 0,
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES public.profiles(id)
);
INSERT INTO public.club_schedule(dow,training_type_id,tier,label,duration_minutes,sort_order)
SELECT v.dow, t.id, v.tier, v.label, 90, v.dow
FROM (VALUES (1,'Technisches Sparring','pflicht','Technisches Sparring'),(2,'Sandsack / Rundenarbeit','ergaenzung','Sandsack'),
             (3,'Techniktraining','pflicht','Technik / Pratzen'),(4,'Krafttraining','ergaenzung','Athletik / Kraft'),
             (6,'Technisches Sparring','pflicht','Technisches Sparring')) v(dow,type_name,tier,label)
JOIN public.training_types t ON t.name=v.type_name
WHERE NOT EXISTS (SELECT 1 FROM public.club_schedule);

ALTER TABLE public.training_submissions ADD COLUMN IF NOT EXISTS club_tier text;
ALTER TABLE public.training_submissions DROP CONSTRAINT IF EXISTS training_submissions_club_tier_check;
ALTER TABLE public.training_submissions ADD CONSTRAINT training_submissions_club_tier_check CHECK (club_tier IS NULL OR club_tier IN ('pflicht','ergaenzung'));
ALTER TABLE public.gym_sessions ADD COLUMN IF NOT EXISTS club_tier text;
ALTER TABLE public.gym_sessions DROP CONSTRAINT IF EXISTS gym_sessions_club_tier_check;
ALTER TABLE public.gym_sessions ADD CONSTRAINT gym_sessions_club_tier_check CHECK (club_tier IS NULL OR club_tier IN ('pflicht','ergaenzung'));
ALTER TABLE public.gym_sessions ADD COLUMN IF NOT EXISTS slot_id integer REFERENCES public.club_schedule(id);

ALTER TABLE public.club_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_schedule ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.club_tiers, public.club_schedule FROM PUBLIC, anon, authenticated;

-- Pflicht-Quest (nur Wettkämpfer)
ALTER TABLE public.quest_definitions ADD COLUMN IF NOT EXISTS only_groups text[];
ALTER TABLE public.quest_definitions DROP CONSTRAINT IF EXISTS quest_definitions_metric_check;
ALTER TABLE public.quest_definitions ADD CONSTRAINT quest_definitions_metric_check CHECK (metric IN ('sessions','box_sessions','technique_minutes',
 'recovery_sessions','recovery_minutes','home_minutes','jogging_km','duels','plan_pct','weekly_all','pflicht_days'));
INSERT INTO public.quest_definitions(key,kind,title,description,metric,target,group_targets,exp,coins,sort_order,only_groups) VALUES
 ('pflicht','weekly','Alle {n} Pflichttrainings','Mo, Mi und Sa im Gym – vom Coach bestätigt','pflicht_days',3,'{}',0,80,5,'{wettkampf}')
ON CONFLICT(key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen (nicht aufrufbar für Clients)
-- Wert eines Trainings: bestätigt → max(Stufenwert, Punkte der Trainingsart), sonst 0.
CREATE OR REPLACE FUNCTION league_private.training_value(p_sub uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT CASE WHEN s.status<>'approved' THEN 0 ELSE GREATEST(coalesce(ct.exp,0), t.points) END
 FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
 LEFT JOIN public.club_tiers ct ON ct.tier=s.club_tier
 WHERE s.id=p_sub
$fn$;

-- Punktebuchung eines bestätigten Trainings auf den aktuellen Wert setzen (genau eine Buchung pro Training).
-- Mit p_old_submission wird die Änderung in training_audit festgehalten. Abgeschlossene Saisons bleiben unverändert.
CREATE OR REPLACE FUNCTION league_private.apply_training_value(p_sub uuid, p_actor uuid, p_note text, p_old_submission jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE s public.training_submissions; tx public.point_transactions; v integer; old_tx jsonb; new_tx jsonb;
BEGIN
 SELECT * INTO s FROM public.training_submissions x WHERE x.id=p_sub FOR UPDATE;
 IF NOT FOUND OR s.status<>'approved' THEN RETURN NULL; END IF;
 IF EXISTS (SELECT 1 FROM public.league_seasons_v21 z WHERE z.status='closed' AND s.training_date BETWEEN z.starts_on AND z.ends_on) THEN RETURN NULL; END IF;
 SELECT * INTO tx FROM public.point_transactions x WHERE x.submission_id=s.id FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 v := league_private.training_value(s.id);
 IF tx.points=v AND tx.exp=v THEN
  RETURN pg_catalog.jsonb_build_object('submission_id',s.id,'old',tx.points,'new',v,'changed',false);
 END IF;
 old_tx := pg_catalog.to_jsonb(tx);
 UPDATE public.point_transactions x SET points=v, exp=v, description=coalesce(p_note,x.description)
 WHERE x.id=tx.id RETURNING pg_catalog.to_jsonb(x.*) INTO new_tx;
 IF p_old_submission IS NOT NULL THEN
  INSERT INTO public.training_audit(submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
  VALUES (s.id,p_actor,p_old_submission,pg_catalog.to_jsonb(s),old_tx,new_tx);
 END IF;
 RETURN pg_catalog.jsonb_build_object('submission_id',s.id,'old',tx.points,'new',v,'changed',true);
END;
$fn$;

-- Stufe der Vereinseinheit an einem Tag (erste aktive Einheit, gleiche Trainingsart bevorzugt).
CREATE OR REPLACE FUNCTION league_private.club_slot_for(p_date date, p_type bigint)
RETURNS public.club_schedule LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT x.* FROM public.club_schedule x WHERE x.is_active AND x.dow=extract(isodow FROM p_date)::integer
 ORDER BY (x.training_type_id=p_type) DESC, x.sort_order, x.id LIMIT 1
$fn$;

CREATE OR REPLACE FUNCTION league_private.tier_label(p text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$ SELECT t.label FROM public.club_tiers t WHERE t.tier=p $fn$;

CREATE OR REPLACE FUNCTION league_private.slot_json(x public.club_schedule)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object('id',x.id,'dow',x.dow,'day',x.dow-1,
  'day_name',(ARRAY['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'])[x.dow],
  'training_type_id',x.training_type_id,'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=x.training_type_id),
  'tier',x.tier,'tier_label',league_private.tier_label(x.tier),'label',x.label,'duration_minutes',x.duration_minutes,'is_active',x.is_active)
$fn$;

-- Automatischer Wochenplan aus dem Stundenplan (Format wie training_plans.items, plus Stufe).
CREATE OR REPLACE FUNCTION league_private.auto_plan_items()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('day',x.dow-1,'type_id',x.training_type_id,'minutes',x.duration_minutes,
   'tier',x.tier,'label',x.label,'slot_id',x.id) ORDER BY x.dow, x.sort_order, x.id),'[]'::jsonb)
 FROM public.club_schedule x WHERE x.is_active
$fn$;

-- Erledigt: bestätigtes Training an diesem Tag mit gleicher Art oder als Vereinstraining eingestuft.
CREATE OR REPLACE FUNCTION league_private.plan_item_done(p_profile uuid, p_date date, p_type bigint, p_auto boolean)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.boxer_id=p_profile AND s.status='approved' AND s.training_date=p_date
   AND (s.training_type_id=p_type OR (p_auto AND s.club_tier IS NOT NULL)))
$fn$;

CREATE OR REPLACE FUNCTION league_private.pflicht_days(p_profile uuid, p_from date, p_to date)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT count(DISTINCT s.training_date)::integer FROM public.training_submissions s
 WHERE s.boxer_id=p_profile AND s.status='approved' AND s.club_tier='pflicht' AND s.training_date BETWEEN p_from AND p_to
$fn$;

-- Pflichtquote: diese Woche und die letzten 4 abgeschlossenen Wochen.
CREATE OR REPLACE FUNCTION league_private.pflicht_info(p_profile uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE ct public.club_tiers; g public.training_groups := league_private.group_of(p_profile); target integer; ws date; done4 integer;
BEGIN
 SELECT * INTO ct FROM public.club_tiers WHERE tier='pflicht';
 SELECT count(DISTINCT x.dow) INTO target FROM public.club_schedule x WHERE x.is_active AND x.tier='pflicht';
 ws := league_private.week_monday(league_private.zurich_today());
 done4 := league_private.pflicht_days(p_profile, ws-28, ws-1);
 RETURN pg_catalog.jsonb_build_object('required',coalesce(g.id IS NOT NULL AND g.key = ANY(coalesce(ct.required_groups,'{}')),false),'target',target,
  'week',league_private.pflicht_days(p_profile, ws, ws+6),
  'weeks',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('week_start',ws-7*i,'days',league_private.pflicht_days(p_profile, ws-7*i, ws-7*i+6)) ORDER BY i)
           FROM pg_catalog.generate_series(0,4) i),
  'pct_4w',CASE WHEN target>0 THEN LEAST(100, floor(done4*100.0/(target*4)))::integer END);
END;
$fn$;

-- Coins eines Trainings: Grundbetrag aus kg_settings (bei der ersten Gutschrift) plus Stufen-Bonus.
CREATE OR REPLACE FUNCTION league_private.kg_training_coins(p_sub uuid, p_base integer)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT CASE WHEN s.status<>'approved' THEN 0 ELSE GREATEST(coalesce(ct.coins,0), p_base) END
 FROM public.training_submissions s LEFT JOIN public.club_tiers ct ON ct.tier=s.club_tier WHERE s.id=p_sub
$fn$;

-- Einreichen: Boxer können Stufe und «eingetragen von» nicht selbst setzen; Vereinsarten nur über das Gym (Flag gym_training).
CREATE OR REPLACE FUNCTION league_private.training_insert_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE uid uuid := auth.uid(); me public.profiles; tname text;
BEGIN
 IF uid IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO me FROM public.profiles p WHERE p.auth_user_id=uid LIMIT 1;
 IF me.id IS NOT NULL AND me.role IN ('admin','coach') AND me.is_active THEN RETURN NEW; END IF;
 NEW.club_tier := NULL;
 NEW.recorded_by := NULL;
 SELECT t.name INTO tname FROM public.training_types t WHERE t.id=NEW.training_type_id AND t.club_only;
 IF tname IS NOT NULL AND league_private.flag_on('gym_training') THEN
  RAISE EXCEPTION '«%» ist ein Vereinstraining und wird im Gym per Check-in erfasst. Selbst eintragen kannst du Heimtraining.', tname
   USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END;
$fn$;
DROP TRIGGER IF EXISTS league_training_insert_guard ON public.training_submissions;
CREATE TRIGGER league_training_insert_guard BEFORE INSERT ON public.training_submissions
 FOR EACH ROW EXECUTE FUNCTION league_private.training_insert_guard();

REVOKE ALL ON FUNCTION league_private.training_value(uuid), league_private.apply_training_value(uuid,uuid,text,jsonb),
 league_private.club_slot_for(date,bigint), league_private.tier_label(text), league_private.slot_json(public.club_schedule),
 league_private.auto_plan_items(), league_private.plan_item_done(uuid,date,bigint,boolean), league_private.pflicht_days(uuid,date,date),
 league_private.pflicht_info(uuid), league_private.kg_training_coins(uuid,integer), league_private.training_insert_guard()
 FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Bestehende Funktionen erweitern
-- Admin/Coach-Korrektur: Punkte = Wert des Trainings (inkl. Stufe), sonst unverändert wie Produktion.
CREATE OR REPLACE FUNCTION public.admin_edit_training(p_submission_id uuid, p_boxer_id uuid, p_training_type_id bigint, p_training_date date, p_notes text, p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
 v_admin public.profiles%rowtype;
 v_old public.training_submissions%rowtype;
 v_new public.training_submissions%rowtype;
 v_old_tx jsonb;
 v_new_tx jsonb;
 v_points integer;
 v_tx_id uuid;
BEGIN
 SELECT * INTO v_admin FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role IN ('admin','coach') AND is_active=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Trainer dürfen Trainings bearbeiten'; END IF;
 IF p_status NOT IN ('pending','approved','rejected') OR p_status IS NULL THEN
  RAISE EXCEPTION 'Ungültiger Status';
 END IF;
 IF p_boxer_id IS NULL OR p_training_type_id IS NULL OR p_training_date IS NULL THEN
  RAISE EXCEPTION 'Boxer, Trainingsart und Datum sind erforderlich';
 END IF;
 PERFORM 1 FROM public.profiles WHERE id=p_boxer_id AND role IN ('boxer','coach');
 IF NOT FOUND THEN RAISE EXCEPTION 'Boxer nicht gefunden'; END IF;
 SELECT points INTO v_points FROM public.training_types
 WHERE id=p_training_type_id AND is_active=true;
 IF NOT FOUND OR v_points IS NULL OR v_points<0 THEN
  RAISE EXCEPTION 'Trainingsart ungültig oder inaktiv';
 END IF;

 SELECT * INTO v_old FROM public.training_submissions
 WHERE id=p_submission_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden'; END IF;

 SELECT id INTO v_tx_id FROM public.point_transactions
 WHERE submission_id=p_submission_id ORDER BY created_at LIMIT 1 FOR UPDATE;
 SELECT to_jsonb(t) INTO v_old_tx FROM public.point_transactions t WHERE id=v_tx_id;
 IF (SELECT count(*) FROM public.point_transactions WHERE submission_id=p_submission_id)>1 THEN
  RAISE EXCEPTION 'Mehrere Punktebuchungen vorhanden: manuelle Prüfung erforderlich';
 END IF;

 UPDATE public.training_submissions SET
 boxer_id=p_boxer_id, training_type_id=p_training_type_id,
 training_date=p_training_date, notes=p_notes,
 status=p_status,
 reviewed_by=CASE WHEN p_status='pending' THEN null ELSE v_admin.id END,
 reviewed_at=CASE WHEN p_status='pending' THEN null ELSE now() END
 WHERE id=p_submission_id RETURNING * INTO v_new;

 -- Etappe 6a: Wert inklusive Vereinsstufe (Pflicht/Ergänzung)
 v_points := league_private.training_value(p_submission_id);

 IF v_tx_id IS NOT NULL THEN
  UPDATE public.point_transactions SET
   boxer_id=p_boxer_id,
   points=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   exp=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   effective_date=p_training_date,
   created_by=v_admin.id,
   description=CASE WHEN p_status='approved' THEN 'Training (admin-korrigiert)' ELSE 'Training (widerrufen)' END
  WHERE id=v_tx_id;
 ELSIF p_status='approved' THEN
  INSERT INTO public.point_transactions
  (boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
  VALUES (p_boxer_id,p_submission_id,v_points,v_points,'training',
          'Training (admin-korrigiert)',p_training_date,v_admin.id)
  RETURNING id INTO v_tx_id;
 END IF;
 SELECT to_jsonb(t) INTO v_new_tx FROM public.point_transactions t WHERE id=v_tx_id;
 INSERT INTO public.training_audit
 (submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
 VALUES (p_submission_id,v_admin.id,to_jsonb(v_old),to_jsonb(v_new),v_old_tx,v_new_tx);

 -- Recalculate both sides of a transfer, and the affected dates/streaks.
 IF v_admin.role='coach' THEN
  PERFORM league_private.coach_training_bonus_refresh(v_old.boxer_id);
 ELSE
  PERFORM public.recalculate_boxer_bonuses(v_old.boxer_id);
 END IF;
 IF v_old.boxer_id IS DISTINCT FROM p_boxer_id THEN
  IF v_admin.role='coach' THEN
   PERFORM league_private.coach_training_bonus_refresh(p_boxer_id);
  ELSE
   PERFORM public.recalculate_boxer_bonuses(p_boxer_id);
  END IF;
 END IF;

 RETURN jsonb_build_object('status',p_status,
  'points',CASE WHEN p_status='approved' THEN v_points ELSE 0 END);
END;
$function$;

-- Coins: Grundbetrag wie bisher, Stufen-Bonus als Korrekturbuchung «Vereinstraining».
CREATE OR REPLACE FUNCTION league_private.kg_sync(p uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE st public.kg_settings;
BEGIN
 IF p IS NULL THEN RETURN; END IF;
 SELECT * INTO st FROM public.kg_settings WHERE id=1;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('kg_wallet:'||p::text));
 IF st.start_coins>0 THEN
  INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note) VALUES (p,st.start_coins,'start','start','Startguthaben')
  ON CONFLICT (profile_id,reason,ref) DO NOTHING;
 END IF;
 IF st.coins_per_training>0 THEN
  INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note)
  SELECT s.boxer_id, st.coins_per_training, 'training', s.id::text, 'Bestätigtes Training vom '||pg_catalog.to_char(s.training_date,'DD.MM.YYYY')
  FROM public.training_submissions s WHERE s.boxer_id=p AND s.status='approved'
  ON CONFLICT (profile_id,reason,ref) DO NOTHING;
 END IF;
 -- Training nicht mehr bestätigt, wieder bestätigt oder Stufe geändert: Differenz als Korrektur buchen.
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note)
 SELECT p, x.want-x.have, 'training_fix', x.base||':'||(x.fixes+1)::text,
        CASE WHEN x.want=0 THEN 'Training nicht mehr bestätigt'
             WHEN x.have<=0 THEN 'Training wieder bestätigt'
             WHEN x.tier IS NOT NULL THEN 'Vereinstraining: '||league_private.tier_label(x.tier)
             ELSE 'Training umgewertet' END
 FROM (SELECT g.base, g.have, g.fixes, s.club_tier AS tier,
         CASE WHEN s.id IS NOT NULL AND s.status='approved' THEN league_private.kg_training_coins(s.id, g.credit) ELSE 0 END AS want
       FROM (SELECT b.base, sum(b.amount)::integer AS have, count(*) FILTER (WHERE b.reason='training_fix')::integer AS fixes,
               coalesce(max(b.amount) FILTER (WHERE b.reason='training'),0)::integer AS credit
             FROM (SELECT pg_catalog.split_part(l.ref,':',1) AS base, l.amount, l.reason
                   FROM public.kg_ledger l WHERE l.profile_id=p AND l.reason IN ('training','training_fix')) b
             GROUP BY b.base) g
       LEFT JOIN public.training_submissions s ON s.id::text=g.base AND s.boxer_id=p) x
 WHERE x.want<>x.have
 ON CONFLICT (profile_id,reason,ref) DO NOTHING;
 -- Abgeholte Quest-Coins (Etappe 3)
 WITH c AS (
  UPDATE public.quest_claims q SET coins_credited_at=now()
  WHERE q.profile_id=p AND q.coins_credited_at IS NULL AND q.coins>0
  RETURNING q.id, q.coins, q.quest_key, q.period_start)
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note)
 SELECT p, c.coins, 'quest', c.id::text, 'Quest '||c.quest_key||' ('||pg_catalog.to_char(c.period_start,'DD.MM.')||')' FROM c
 ON CONFLICT (profile_id,reason,ref) DO NOTHING;
END;
$fn$;

-- Kampfpfad: Trainings nach Stufe (Pflicht 15, Ergänzung 12, sonst kp_training).
CREATE OR REPLACE FUNCTION league_private.kg_pass_points(p uuid, p_month date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE s public.kg_pass_settings; m0 date := league_private.kg_month(p_month); m1 date; tr integer; trp integer; tre integer; qw integer; qd integer; qc integer; dp integer; dw integer;
 pt integer; pq integer; pd integer; total integer;
BEGIN
 m1 := (m0 + interval '1 month')::date;
 SELECT * INTO s FROM public.kg_pass_settings WHERE id=1;
 SELECT count(*), count(*) FILTER (WHERE t.club_tier='pflicht'), count(*) FILTER (WHERE t.club_tier='ergaenzung'),
        coalesce(sum(coalesce(ct.pass_points, s.kp_training)),0)
 INTO tr, trp, tre, pt
 FROM public.training_submissions t LEFT JOIN public.club_tiers ct ON ct.tier=t.club_tier
 WHERE t.boxer_id=p AND t.status='approved' AND t.training_date>=m0 AND t.training_date<m1;
 SELECT count(*) FILTER (WHERE d.kind='weekly'), count(*) FILTER (WHERE d.kind='daily'), count(*) FILTER (WHERE d.kind='chest')
 INTO qw, qd, qc
 FROM public.quest_claims c JOIN public.quest_definitions d ON d.key=c.quest_key
 WHERE c.profile_id=p AND (c.claimed_at AT TIME ZONE 'Europe/Zurich')::date>=m0 AND (c.claimed_at AT TIME ZONE 'Europe/Zurich')::date<m1;
 SELECT count(*) INTO dp FROM public.league_duels d
  WHERE p IN (d.challenger_id,d.opponent_id) AND d.status IN ('active','awaiting_reviews','settled') AND d.accepted_at IS NOT NULL
    AND (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date>=m0 AND (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date<m1;
 SELECT count(*) INTO dw FROM public.league_duels d
  WHERE d.status='settled' AND d.winner_id=p AND d.settled_at IS NOT NULL
    AND (d.settled_at AT TIME ZONE 'Europe/Zurich')::date>=m0 AND (d.settled_at AT TIME ZONE 'Europe/Zurich')::date<m1;
 pq := qw*s.kp_quest_weekly + qd*s.kp_quest_daily + qc*s.kp_quest_chest; pd := dp*s.kp_duel_played + dw*s.kp_duel_won;
 total := pt+pq+pd;
 RETURN pg_catalog.jsonb_build_object('month',m0,'trainings',tr,'trainings_pflicht',trp,'trainings_ergaenzung',tre,
  'quests_weekly',qw,'quests_daily',qd,'quests_chest',qc,'duels_played',dp,'duels_won',dw,
  'points_trainings',pt,'points_quests',pq,'points_duels',pd,'total',total,'per_tier',s.kp_per_tier,'tier',LEAST(30,total/s.kp_per_tier));
END;
$fn$;

-- Quests: neue Kennzahl pflicht_days, Quests nur für bestimmte Gruppen.
CREATE OR REPLACE FUNCTION league_private.quest_progress(p_profile uuid, p_metric text, p_from date, p_to date)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v numeric;
BEGIN
 IF p_metric='duels' THEN
  SELECT count(*) INTO v FROM public.league_duels d
  WHERE p_profile IN (d.challenger_id, d.opponent_id) AND d.status IN ('active','awaiting_reviews','settled')
    AND d.accepted_at IS NOT NULL AND (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date BETWEEN p_from AND p_to;
  RETURN v;
 ELSIF p_metric='plan_pct' THEN
  RETURN league_private.plan_pct(p_profile, p_from);
 ELSIF p_metric='pflicht_days' THEN
  RETURN league_private.pflicht_days(p_profile, p_from, p_to);
 END IF;
 SELECT CASE p_metric
   WHEN 'sessions' THEN count(*)
   WHEN 'box_sessions' THEN count(*) FILTER (WHERE t.category IN ('Boxen','Wettkampf'))
   WHEN 'technique_minutes' THEN coalesce(sum(coalesce(s.technique_minutes,s.duration_minutes,0)) FILTER (WHERE t.name='Techniktraining'),0)
   WHEN 'recovery_sessions' THEN count(*) FILTER (WHERE t.name='Mobilität / Regeneration')
   WHEN 'recovery_minutes' THEN coalesce(sum(coalesce(s.duration_minutes,0)) FILTER (WHERE t.name='Mobilität / Regeneration'),0)
   WHEN 'home_minutes' THEN coalesce(sum(coalesce(s.duration_minutes,0)) FILTER (WHERE t.name IN ('Schattenboxen / Heimtraining','Seilspringen / Konditionszirkel')),0)
   WHEN 'jogging_km' THEN coalesce(sum(coalesce(s.jogging_km,0)) FILTER (WHERE t.name='Joggen'),0)
   ELSE 0 END
 INTO v
 FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
 WHERE s.boxer_id=p_profile AND s.status='approved' AND s.training_date BETWEEN p_from AND p_to;
 RETURN coalesce(v,0);
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.quest_state(p_profile uuid, d public.quest_definitions, p_from date, p_to date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE tgt integer := league_private.quest_target(d, p_profile); prog numeric; avail boolean := true; c public.quest_claims;
BEGIN
 prog := league_private.quest_progress(p_profile, d.metric, p_from, p_to);
 IF d.metric='plan_pct' AND prog IS NULL THEN avail := false; prog := 0; END IF;
 IF d.metric='duels' AND NOT league_private.flag_on('duels') THEN avail := false; END IF;
 IF d.only_groups IS NOT NULL AND coalesce((league_private.group_of(p_profile)).key,'') <> ALL(d.only_groups) THEN avail := false; END IF;
 SELECT * INTO c FROM public.quest_claims x WHERE x.profile_id=p_profile AND x.quest_key=d.key AND x.period_start=p_from;
 RETURN pg_catalog.jsonb_build_object('key',d.key,'kind',d.kind,'metric',d.metric,'title',league_private.quest_title(d,tgt),
  'description',d.description,'target',tgt,'progress',prog,'exp',coalesce(c.exp,d.exp),'coins',coalesce(c.coins,d.coins),
  'available',avail OR c.id IS NOT NULL,'done',c.id IS NOT NULL OR (avail AND prog>=tgt),'claimed',c.id IS NOT NULL,'claimed_at',c.claimed_at,
  'period_start',p_from,'only_groups',d.only_groups);
END;
$fn$;

-- Wochenplan-Quest: veröffentlichter Plan der Gruppe, sonst automatischer Plan aus dem Stundenplan
-- (dann zählt das Wochenziel der Gruppe: z. B. Newcomer 2 von 5 Einheiten = 100 %).
CREATE OR REPLACE FUNCTION league_private.plan_pct(p_profile uuid, p_week date)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE g public.training_groups := league_private.group_of(p_profile); pl public.training_plans; ws date := league_private.week_monday(p_week);
 items jsonb; total integer; done integer; need integer;
BEGIN
 IF g.id IS NULL THEN RETURN NULL; END IF;
 SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=ws AND x.published_at IS NOT NULL;
 IF pl.id IS NOT NULL THEN
  total := pg_catalog.jsonb_array_length(pl.items);
  IF total=0 THEN RETURN NULL; END IF;
  SELECT count(*) INTO done FROM pg_catalog.jsonb_array_elements(pl.items) it
  WHERE league_private.plan_item_done(p_profile, pl.week_start+(it->>'day')::integer, (it->>'type_id')::bigint, false);
  RETURN floor(done*100.0/total)::integer;
 END IF;
 items := league_private.auto_plan_items();
 total := pg_catalog.jsonb_array_length(items);
 IF total=0 THEN RETURN NULL; END IF;
 SELECT count(*) INTO done FROM pg_catalog.jsonb_array_elements(items) it
 WHERE league_private.plan_item_done(p_profile, ws+(it->>'day')::integer, (it->>'type_id')::bigint, true);
 need := GREATEST(1, LEAST(total, g.weekly_target));
 RETURN LEAST(100, floor(done*100.0/need))::integer;
END;
$fn$;

-- ---------------------------------------------------------------------------
-- Gym: Einheit aus dem Stundenplan, Stufe, nachträglich ändern
CREATE OR REPLACE FUNCTION public.staff_open_gym_session(p_training_type_id bigint, p_duration_minutes integer, p_note text, p_group_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); t public.training_types; g public.training_groups; new_id bigint; note text;
 sl public.club_schedule; today date := league_private.zurich_today();
BEGIN
 SELECT * INTO t FROM public.training_types x WHERE x.id=p_training_type_id AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte eine gültige Trainingsart wählen' USING ERRCODE='22023'; END IF;
 IF t.name='Joggen' THEN RAISE EXCEPTION 'Joggen bitte einzeln mit Distanz eintragen, nicht über den Gym-Check-in' USING ERRCODE='22023'; END IF;
 IF p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 1 AND 1440 THEN RAISE EXCEPTION 'Bitte die Dauer in Minuten angeben' USING ERRCODE='22023'; END IF;
 note := pg_catalog.btrim(coalesce(p_note,''));
 IF pg_catalog.char_length(note)<3 OR pg_catalog.char_length(note)>500 THEN RAISE EXCEPTION 'Bitte eine Bemerkung für alle angeben (mindestens 3 Zeichen)' USING ERRCODE='22023'; END IF;
 IF p_group_key IS NOT NULL AND p_group_key<>'' THEN
  SELECT * INTO g FROM public.training_groups x WHERE x.key=p_group_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 END IF;
 sl := league_private.club_slot_for(today, t.id);
 INSERT INTO public.gym_sessions(session_date,training_type_id,duration_minutes,note,group_id,opened_by,club_tier,slot_id)
 VALUES (today,t.id,p_duration_minutes,note,g.id,me.id,sl.tier,sl.id) RETURNING id INTO new_id;
 RETURN pg_catalog.jsonb_build_object('id',new_id,'session_date',today,'club_tier',sl.tier,'tier_label',league_private.tier_label(sl.tier));
END;
$fn$;

-- Heutige Einheit aus dem Stundenplan mit einem Tippen öffnen (bereits offene Einheit wird zurückgegeben).
CREATE OR REPLACE FUNCTION public.staff_open_club_session(p_slot_id integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); sl public.club_schedule; today date := league_private.zurich_today(); ex bigint; r jsonb;
BEGIN
 SELECT * INTO sl FROM public.club_schedule x WHERE x.id=p_slot_id AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Diese Einheit gibt es im Stundenplan nicht' USING ERRCODE='22023'; END IF;
 IF sl.dow<>extract(isodow FROM today)::integer THEN RAISE EXCEPTION 'Diese Einheit steht heute nicht im Stundenplan' USING ERRCODE='22023'; END IF;
 SELECT s.id INTO ex FROM public.gym_sessions s WHERE s.slot_id=sl.id AND s.session_date=today AND s.status<>'cancelled' ORDER BY s.id LIMIT 1;
 IF ex IS NOT NULL THEN RETURN pg_catalog.jsonb_build_object('id',ex,'session_date',today,'existing',true); END IF;
 r := public.staff_open_gym_session(sl.training_type_id, sl.duration_minutes, sl.label, NULL);
 UPDATE public.gym_sessions s SET slot_id=sl.id, club_tier=sl.tier WHERE s.id=(r->>'id')::bigint;
 RETURN pg_catalog.jsonb_build_object('id',(r->>'id')::bigint,'session_date',today,'existing',false,'club_tier',sl.tier,'tier_label',league_private.tier_label(sl.tier));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_list_gym_sessions(p_days integer DEFAULT 14)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff();
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'session_date',s.session_date,'status',s.status,
   'training_type',t.name,'training_type_id',s.training_type_id,'duration_minutes',s.duration_minutes,'note',s.note,
   'group',(SELECT g.key FROM public.training_groups g WHERE g.id=s.group_id),
   'club_tier',s.club_tier,'tier_label',league_private.tier_label(s.club_tier),'slot_id',s.slot_id,
   'opened_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=s.opened_by),
   'present',(SELECT count(*) FROM public.gym_attendance a WHERE a.session_id=s.id),
   'confirmed',(SELECT count(*) FROM public.gym_attendance a WHERE a.session_id=s.id AND a.submission_id IS NOT NULL))
   ORDER BY s.session_date DESC, s.id DESC)
  FROM public.gym_sessions s JOIN public.training_types t ON t.id=s.training_type_id
  WHERE s.session_date >= league_private.zurich_today() - LEAST(GREATEST(coalesce(p_days,14),1),120)),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_get_gym_session(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Einheit nicht gefunden' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('id',s.id,'session_date',s.session_date,'status',s.status,'duration_minutes',s.duration_minutes,'note',s.note,
  'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=s.training_type_id),'training_type_id',s.training_type_id,
  'club_tier',s.club_tier,'tier_label',league_private.tier_label(s.club_tier),'slot_id',s.slot_id,
  'editable',s.status<>'cancelled' AND NOT EXISTS (SELECT 1 FROM public.league_seasons_v21 z WHERE z.status='closed' AND s.session_date BETWEEN z.starts_on AND z.ends_on),
  'group',(SELECT g.key FROM public.training_groups g WHERE g.id=s.group_id),
  'people',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,'is_self',p.id=me.id,
     'group',(SELECT g.key FROM public.training_group_members m JOIN public.training_groups g ON g.id=m.group_id WHERE m.profile_id=p.id),
     'present',a.profile_id IS NOT NULL,'source',a.source,'confirmed',a.submission_id IS NOT NULL,'skipped_reason',a.skipped_reason,
     'points',CASE WHEN a.submission_id IS NOT NULL THEN (SELECT x.points FROM public.point_transactions x WHERE x.submission_id=a.submission_id) END)
     ORDER BY pg_catalog.lower(p.display_name))
    FROM public.profiles p LEFT JOIN public.gym_attendance a ON a.session_id=s.id AND a.profile_id=p.id
    WHERE (p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')) OR a.profile_id IS NOT NULL),'[]'::jsonb));
END;
$fn$;

-- Alle Anwesenden bestätigen (wie bisher) und die Stufe der Einheit auf die Trainings übertragen.
CREATE OR REPLACE FUNCTION public.staff_confirm_gym_session(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions; a record; r jsonb; sid uuid;
 n integer := 0; pts integer := 0; skipped jsonb := '[]'::jsonb; reason text;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'open' THEN RAISE EXCEPTION 'Diese Einheit ist schon abgeschlossen' USING ERRCODE='55000'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.gym_attendance x WHERE x.session_id=s.id) THEN RAISE EXCEPTION 'Noch niemand als anwesend markiert' USING ERRCODE='22023'; END IF;
 FOR a IN SELECT x.profile_id, p.display_name, p.role, p.is_active, p.archived_at FROM public.gym_attendance x JOIN public.profiles p ON p.id=x.profile_id
          WHERE x.session_id=s.id AND x.submission_id IS NULL ORDER BY pg_catalog.lower(p.display_name) LOOP
  reason := NULL;
  IF a.profile_id=me.id THEN reason := 'eigenes Training – bitte normal einreichen';
  ELSIF a.role NOT IN ('boxer','coach') OR NOT a.is_active OR a.archived_at IS NOT NULL THEN reason := 'Profil nicht aktiv';
  ELSIF EXISTS (SELECT 1 FROM public.training_submissions t WHERE t.boxer_id=a.profile_id AND t.training_date=s.session_date
                AND t.training_type_id=s.training_type_id AND t.status IN ('pending','approved')) THEN reason := 'hat dieses Training schon eingereicht';
  END IF;
  IF reason IS NOT NULL THEN
   UPDATE public.gym_attendance x SET skipped_reason=reason WHERE x.session_id=s.id AND x.profile_id=a.profile_id;
   skipped := skipped || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('name',a.display_name,'reason',reason));
   CONTINUE;
  END IF;
  r := public.staff_record_training(a.profile_id, s.training_type_id, s.session_date, s.duration_minutes, s.note, NULL,
        pg_catalog.md5('gym:'||s.id::text||':'||a.profile_id::text)::uuid);
  sid := (r->>'submission_id')::uuid;
  IF s.club_tier IS NOT NULL AND league_private.flag_on('gym_training') THEN
   UPDATE public.training_submissions x SET club_tier=s.club_tier WHERE x.id=sid;
   PERFORM league_private.apply_training_value(sid, me.id, 'Bestätigtes Training ('||league_private.tier_label(s.club_tier)||')', NULL);
  END IF;
  UPDATE public.gym_attendance x SET submission_id=sid, skipped_reason=NULL WHERE x.session_id=s.id AND x.profile_id=a.profile_id;
  n := n+1; pts := pts+coalesce((SELECT x.points FROM public.point_transactions x WHERE x.submission_id=sid),0);
 END LOOP;
 UPDATE public.gym_sessions x SET status='confirmed', confirmed_at=now(), confirmed_by=me.id WHERE x.id=s.id;
 RETURN pg_catalog.jsonb_build_object('confirmed',n,'points_awarded',pts,'skipped',skipped,'club_tier',CASE WHEN league_private.flag_on('gym_training') THEN s.club_tier END);
END;
$fn$;

-- Einheit umstellen (Trainingsart und/oder Stufe). Bestätigte Einheiten: alle Trainings der Anwesenden werden nachgeführt
-- (Punkte/EXP mit Eintrag in der Änderungshistorie, Coins und Kampfpfad automatisch). Nicht in abgeschlossenen Saisons.
CREATE OR REPLACE FUNCTION public.staff_update_gym_session(p_session_id bigint, p_training_type_id bigint, p_tier text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions; t public.training_types; v_tier text; sub public.training_submissions;
 v_old jsonb; n integer := 0; before_pts integer := 0; after_pts integer := 0;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Einheit nicht gefunden' USING ERRCODE='22023'; END IF;
 IF s.status='cancelled' THEN RAISE EXCEPTION 'Abgebrochene Einheiten können nicht geändert werden' USING ERRCODE='55000'; END IF;
 SELECT * INTO t FROM public.training_types x WHERE x.id=coalesce(p_training_type_id,s.training_type_id) AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte eine gültige Trainingsart wählen' USING ERRCODE='22023'; END IF;
 IF t.name='Joggen' THEN RAISE EXCEPTION 'Joggen bitte einzeln mit Distanz eintragen, nicht über den Gym-Check-in' USING ERRCODE='22023'; END IF;
 v_tier := NULLIF(NULLIF(pg_catalog.btrim(coalesce(p_tier,'')),''),'none');
 IF v_tier IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.club_tiers c WHERE c.tier=v_tier) THEN RAISE EXCEPTION 'Unbekannte Stufe' USING ERRCODE='22023'; END IF;
 IF EXISTS (SELECT 1 FROM public.league_seasons_v21 z WHERE z.status='closed' AND s.session_date BETWEEN z.starts_on AND z.ends_on) THEN
  RAISE EXCEPTION 'Diese Einheit gehört zu einer abgeschlossenen Saison und kann nicht mehr geändert werden' USING ERRCODE='22023';
 END IF;
 IF s.status='confirmed' AND NOT league_private.flag_on('gym_training') THEN
  RAISE EXCEPTION 'Bestätigte Einheiten lassen sich ändern, sobald «Training im Gym» freigeschaltet ist' USING ERRCODE='42501';
 END IF;
 UPDATE public.gym_sessions x SET training_type_id=t.id, club_tier=v_tier WHERE x.id=s.id;
 IF s.status='confirmed' THEN
  FOR sub IN SELECT x.* FROM public.gym_attendance a JOIN public.training_submissions x ON x.id=a.submission_id
             WHERE a.session_id=s.id AND x.status='approved' ORDER BY x.id FOR UPDATE OF x LOOP
   v_old := pg_catalog.to_jsonb(sub);
   before_pts := before_pts + coalesce((SELECT x.points FROM public.point_transactions x WHERE x.submission_id=sub.id),0);
   UPDATE public.training_submissions x SET club_tier=v_tier WHERE x.id=sub.id;
   IF sub.training_type_id<>t.id THEN
    PERFORM public.admin_edit_training(sub.id, sub.boxer_id, t.id, sub.training_date, sub.notes, 'approved');
    UPDATE public.training_submissions x SET technique_minutes=CASE WHEN t.name='Techniktraining' THEN x.duration_minutes END WHERE x.id=sub.id;
   ELSE
    PERFORM league_private.apply_training_value(sub.id, me.id, 'Training (Stufe geändert)', v_old);
   END IF;
   after_pts := after_pts + coalesce((SELECT x.points FROM public.point_transactions x WHERE x.submission_id=sub.id),0);
   n := n+1;
  END LOOP;
 END IF;
 RETURN pg_catalog.jsonb_build_object('id',s.id,'status',s.status,'training_type',t.name,'club_tier',v_tier,'tier_label',league_private.tier_label(v_tier),
  'updated_trainings',n,'points_before',before_pts,'points_after',after_pts);
END;
$fn$;

-- Einzelnes bestätigtes Training einstufen (z. B. vom Coach eingetragene Trainings). Erst mit Flag gym_training.
CREATE OR REPLACE FUNCTION public.staff_set_training_tier(p_submission_id uuid, p_tier text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); sub public.training_submissions; v_tier text; v_old jsonb; r jsonb;
BEGIN
 IF NOT league_private.flag_on('gym_training') THEN RAISE EXCEPTION 'Stufen gelten, sobald «Training im Gym» freigeschaltet ist' USING ERRCODE='42501'; END IF;
 SELECT * INTO sub FROM public.training_submissions x WHERE x.id=p_submission_id FOR UPDATE;
 IF NOT FOUND OR sub.status<>'approved' THEN RAISE EXCEPTION 'Nur bestätigte Trainings können eingestuft werden' USING ERRCODE='22023'; END IF;
 IF sub.boxer_id=me.id THEN RAISE EXCEPTION 'Eigene Trainings stuft ein anderer Trainer oder der Admin ein' USING ERRCODE='42501'; END IF;
 IF EXISTS (SELECT 1 FROM public.league_seasons_v21 z WHERE z.status='closed' AND sub.training_date BETWEEN z.starts_on AND z.ends_on) THEN
  RAISE EXCEPTION 'Dieses Training gehört zu einer abgeschlossenen Saison' USING ERRCODE='22023';
 END IF;
 v_tier := NULLIF(NULLIF(pg_catalog.btrim(coalesce(p_tier,'')),''),'none');
 IF v_tier IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.club_tiers c WHERE c.tier=v_tier) THEN RAISE EXCEPTION 'Unbekannte Stufe' USING ERRCODE='22023'; END IF;
 IF sub.club_tier IS NOT DISTINCT FROM v_tier THEN
  RETURN pg_catalog.jsonb_build_object('submission_id',sub.id,'club_tier',v_tier,'changed',false,'points',league_private.training_value(sub.id));
 END IF;
 v_old := pg_catalog.to_jsonb(sub);
 UPDATE public.training_submissions x SET club_tier=v_tier WHERE x.id=sub.id;
 r := league_private.apply_training_value(sub.id, me.id, CASE WHEN v_tier IS NULL THEN 'Training (Stufe entfernt)' ELSE 'Training ('||league_private.tier_label(v_tier)||')' END, v_old);
 RETURN pg_catalog.jsonb_build_object('submission_id',sub.id,'club_tier',v_tier,'tier_label',league_private.tier_label(v_tier),'changed',true,
  'points',league_private.training_value(sub.id));
END;
$fn$;

-- Stufe und Punkte mehrerer Trainings (Coach-Dashboard «Trainings bearbeiten»).
CREATE OR REPLACE FUNCTION public.staff_training_tiers(p_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff();
BEGIN
 IF p_ids IS NULL OR coalesce(pg_catalog.array_length(p_ids,1),0)>100 THEN RAISE EXCEPTION 'Höchstens 100 Trainings auf einmal' USING ERRCODE='22023'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'club_tier',s.club_tier,'tier_label',league_private.tier_label(s.club_tier),
   'points',(SELECT x.points FROM public.point_transactions x WHERE x.submission_id=s.id),'gym',EXISTS (SELECT 1 FROM public.gym_attendance a WHERE a.submission_id=s.id),
   'editable',s.status='approved' AND s.boxer_id<>me.id AND NOT EXISTS (SELECT 1 FROM public.league_seasons_v21 z WHERE z.status='closed' AND s.training_date BETWEEN z.starts_on AND z.ends_on)))
  FROM public.training_submissions s WHERE s.id = ANY(p_ids)),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.my_gym_sessions_today()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role NOT IN ('admin','coach') THEN RETURN '[]'::jsonb; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'training_type',t.name,'duration_minutes',s.duration_minutes,
   'note',s.note,'group',(SELECT g.name FROM public.training_groups g WHERE g.id=s.group_id),
   'club_tier',s.club_tier,'tier_label',league_private.tier_label(s.club_tier),
   'checked_in',EXISTS (SELECT 1 FROM public.gym_attendance a WHERE a.session_id=s.id AND a.profile_id=me.id)) ORDER BY s.id)
  FROM public.gym_sessions s JOIN public.training_types t ON t.id=s.training_type_id
  WHERE s.status='open' AND s.session_date=league_private.zurich_today()),'[]'::jsonb);
END;
$fn$;

-- ---------------------------------------------------------------------------
-- Stundenplan lesen und pflegen
CREATE OR REPLACE FUNCTION public.get_club_schedule()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); staff boolean; today date := league_private.zurich_today();
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 staff := me.role IN ('admin','coach');
 IF NOT league_private.flag_on('gym_training') AND NOT staff THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT league_private.flag_on('gym_training'),'today',today,
  'today_dow',extract(isodow FROM today)::integer,'can_edit',me.role='admin',
  'tiers',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('tier',c.tier,'label',c.label,'exp',c.exp,'coins',c.coins,
     'pass_points',c.pass_points,'required_groups',c.required_groups) ORDER BY c.exp DESC) FROM public.club_tiers c),
  'home',(SELECT pg_catalog.jsonb_build_object('coins',k.coins_per_training,'pass_points',(SELECT ps.kp_training FROM public.kg_pass_settings ps WHERE ps.id=1))
     FROM public.kg_settings k WHERE k.id=1),
  'slots',coalesce((SELECT pg_catalog.jsonb_agg(league_private.slot_json(x) || pg_catalog.jsonb_build_object(
     'today_session',CASE WHEN staff AND x.dow=extract(isodow FROM today)::integer THEN
       (SELECT pg_catalog.jsonb_build_object('id',s.id,'status',s.status) FROM public.gym_sessions s
        WHERE s.slot_id=x.id AND s.session_date=today AND s.status<>'cancelled' ORDER BY s.id LIMIT 1) END)
     ORDER BY x.dow, x.sort_order, x.id) FROM public.club_schedule x WHERE x.is_active OR staff),'[]'::jsonb),
  'club_types',coalesce((SELECT pg_catalog.jsonb_agg(t.name ORDER BY t.sort_order) FROM public.training_types t WHERE t.club_only AND t.is_active),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_save_club_slot(p_slot_id integer, p_dow integer, p_training_type_id bigint, p_tier text,
 p_label text, p_duration_minutes integer, p_active boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); v_tier text; lbl text; x public.club_schedule;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin ändert den Stundenplan' USING ERRCODE='42501'; END IF;
 IF p_dow IS NULL OR p_dow NOT BETWEEN 1 AND 7 THEN RAISE EXCEPTION 'Bitte einen Wochentag wählen' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.training_types t WHERE t.id=p_training_type_id AND t.name<>'Joggen') THEN
  RAISE EXCEPTION 'Bitte eine gültige Trainingsart wählen' USING ERRCODE='22023';
 END IF;
 v_tier := NULLIF(NULLIF(pg_catalog.btrim(coalesce(p_tier,'')),''),'none');
 IF v_tier IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.club_tiers c WHERE c.tier=v_tier) THEN RAISE EXCEPTION 'Unbekannte Stufe' USING ERRCODE='22023'; END IF;
 lbl := pg_catalog.btrim(coalesce(p_label,''));
 IF pg_catalog.char_length(lbl) NOT BETWEEN 3 AND 60 THEN RAISE EXCEPTION 'Bezeichnung mit 3 bis 60 Zeichen' USING ERRCODE='22023'; END IF;
 IF p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 15 AND 600 THEN RAISE EXCEPTION 'Dauer zwischen 15 und 600 Minuten' USING ERRCODE='22023'; END IF;
 IF p_slot_id IS NULL THEN
  INSERT INTO public.club_schedule(dow,training_type_id,tier,label,duration_minutes,is_active,sort_order,updated_by)
  VALUES (p_dow,p_training_type_id,v_tier,lbl,p_duration_minutes,coalesce(p_active,true),p_dow,me.id) RETURNING * INTO x;
 ELSE
  UPDATE public.club_schedule s SET dow=p_dow, training_type_id=p_training_type_id, tier=v_tier, label=lbl, duration_minutes=p_duration_minutes,
   is_active=coalesce(p_active,s.is_active), updated_at=now(), updated_by=me.id WHERE s.id=p_slot_id RETURNING * INTO x;
  IF x.id IS NULL THEN RAISE EXCEPTION 'Einheit nicht gefunden' USING ERRCODE='22023'; END IF;
 END IF;
 RETURN league_private.slot_json(x);
END;
$fn$;

-- ---------------------------------------------------------------------------
-- Wochenplan: automatischer Plan aus dem Stundenplan, solange kein eigener Plan veröffentlicht ist.
CREATE OR REPLACE FUNCTION public.staff_get_training_plan(p_group_key text, p_week_start date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); g public.training_groups; pl public.training_plans;
BEGIN
 SELECT * INTO g FROM public.training_groups x WHERE x.key=p_group_key;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=league_private.week_monday(p_week_start);
 RETURN pg_catalog.jsonb_build_object('group',league_private.group_json(g),'week_start',league_private.week_monday(p_week_start),
  'auto_items',league_private.auto_plan_items(),
  'plan',CASE WHEN pl.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('focus',pl.focus,'items',pl.items,'published_at',pl.published_at,
   'updated_at',pl.updated_at,'updated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=pl.updated_by)) END);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.get_my_week_plan(p_week_start date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); g public.training_groups; pl public.training_plans; ws date; today date := league_private.zurich_today();
 items jsonb; auto boolean := false;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 ws := league_private.week_monday(coalesce(p_week_start,today));
 g := league_private.group_of(me.id);
 IF g.id IS NOT NULL THEN
  SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=ws AND x.published_at IS NOT NULL;
 END IF;
 IF pl.id IS NOT NULL THEN items := pl.items; ELSE items := league_private.auto_plan_items(); auto := true; END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'today',today,'week_start',ws,'group',league_private.group_json(g),
  'trainings',league_private.approved_count(me.id,ws,ws+6),'pflicht',league_private.pflicht_info(me.id),
  'plan',CASE WHEN pg_catalog.jsonb_array_length(items)=0 THEN NULL ELSE pg_catalog.jsonb_build_object('auto',auto,
   'focus',pl.focus,'published_at',pl.published_at,
   'updated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=pl.updated_by),
   'need',CASE WHEN auto THEN LEAST(pg_catalog.jsonb_array_length(items), coalesce(g.weekly_target,pg_catalog.jsonb_array_length(items))) END,
   'items',coalesce((SELECT pg_catalog.jsonb_agg(it || pg_catalog.jsonb_build_object(
      'date',ws+(it->>'day')::integer,
      'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=(it->>'type_id')::bigint),
      'tier_label',league_private.tier_label(it->>'tier'),
      'status',CASE
        WHEN league_private.plan_item_done(me.id, ws+(it->>'day')::integer, (it->>'type_id')::bigint, auto) THEN 'done'
        WHEN EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='pending'
                     AND s.training_type_id=(it->>'type_id')::bigint AND s.training_date=ws+(it->>'day')::integer) THEN 'pending'
        WHEN ws+(it->>'day')::integer < today THEN 'missed'
        WHEN ws+(it->>'day')::integer = today THEN 'today'
        ELSE 'open' END) ORDER BY (it->>'day')::integer, ord)
     FROM pg_catalog.jsonb_array_elements(items) WITH ORDINALITY e(it,ord)),'[]'::jsonb)) END);
END;
$fn$;

-- Präsenz mit Pflichtquote
CREATE OR REPLACE FUNCTION public.get_my_presence()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := league_private.zurich_today(); from_d date;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 from_d := league_private.week_monday(today) - 21;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'today',today,
  'group',league_private.group_json(league_private.group_of(me.id)),
  'days',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('date',d::date,
     'trainings',(SELECT count(*) FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='approved' AND s.training_date=d::date),
     'pending',(SELECT count(*) FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='pending' AND s.training_date=d::date),
     'tier',(SELECT max(s.club_tier) FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='approved' AND s.training_date=d::date),
     'gym',EXISTS (SELECT 1 FROM public.gym_attendance a JOIN public.gym_sessions g ON g.id=a.session_id
                   WHERE a.profile_id=me.id AND g.session_date=d::date AND g.status<>'cancelled')) ORDER BY d)
     FROM pg_catalog.generate_series(from_d::timestamp, (from_d+27)::timestamp, interval '1 day') d),
  'weeks',league_private.presence_weeks(me.id,4),
  'streak_weeks',league_private.presence_streak(me.id),
  'pflicht',league_private.pflicht_info(me.id));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_presence_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff();
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,
   'group',league_private.group_json(league_private.group_of(p.id)),
   'weeks',league_private.presence_weeks(p.id,4),'streak_weeks',league_private.presence_streak(p.id),
   'pflicht',league_private.pflicht_info(p.id),
   'last_training',(SELECT max(s.training_date) FROM public.training_submissions s WHERE s.boxer_id=p.id AND s.status='approved'))
   ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

-- ---------------------------------------------------------------------------
-- Aktivierung und Rücknahme (nur über die Skripte in supabase/production-prep, nicht für Clients)
-- Bestehende Trainings nach Stundenplan einstufen und neu bewerten (Owner-Entscheid 28.10.2026):
--  Vereinsart oder Trainingsart der Einheit an einem Tag mit Vereinseinheit → deren Stufe (Mo/Mi/Sa Pflicht 60, Di/Do Ergänzung 40);
--  Vereinsart an Tagen ohne Vereinseinheit → Heimtraining 30; Sprint-Intervalle 30; alles andere unverändert.
CREATE OR REPLACE FUNCTION league_private.activate_club_tiers(p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE marker text := 'Training (umgewertet nach Stundenplan)'; s public.training_submissions; sl public.club_schedule; t public.training_types;
 r jsonb; old jsonb; n_tier integer := 0; n_changed integer := 0; n_up integer := 0; n_down integer := 0; d_sum integer := 0;
BEGIN
 IF p_actor IS NULL OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=p_actor AND p.role='admin') THEN RAISE EXCEPTION 'Aktivierung nur mit Admin-Profil'; END IF;
 IF EXISTS (SELECT 1 FROM public.training_audit a WHERE a.new_transaction->>'description'=marker) THEN RAISE EXCEPTION 'Bereits aktiviert'; END IF;
 UPDATE public.training_types x SET points=30 WHERE x.name IN ('Reguläres Boxtraining','Techniktraining','Pratzentraining','Sandsack / Rundenarbeit','Sprint-Intervalle');
 UPDATE public.training_types x SET is_active=true WHERE x.name='Technisches Sparring';
 FOR s IN SELECT x.* FROM public.training_submissions x WHERE x.status='approved'
          AND NOT EXISTS (SELECT 1 FROM public.league_seasons_v21 z WHERE z.status='closed' AND x.training_date BETWEEN z.starts_on AND z.ends_on)
          ORDER BY x.training_date, x.id FOR UPDATE LOOP
  old := pg_catalog.to_jsonb(s);
  IF s.club_tier IS NULL AND NOT EXISTS (SELECT 1 FROM public.gym_attendance a WHERE a.submission_id=s.id) THEN
   SELECT * INTO t FROM public.training_types x WHERE x.id=s.training_type_id;
   sl := league_private.club_slot_for(s.training_date, s.training_type_id);
   IF sl.id IS NOT NULL AND sl.tier IS NOT NULL AND (t.club_only OR sl.training_type_id=t.id) THEN
    UPDATE public.training_submissions x SET club_tier=sl.tier WHERE x.id=s.id;
    n_tier := n_tier+1;
   END IF;
  END IF;
  r := league_private.apply_training_value(s.id, p_actor, marker, old);
  IF r IS NOT NULL AND (r->>'changed')::boolean THEN
   n_changed := n_changed+1; d_sum := d_sum + (r->>'new')::integer - (r->>'old')::integer;
   IF (r->>'new')::integer > (r->>'old')::integer THEN n_up := n_up+1; ELSE n_down := n_down+1; END IF;
  END IF;
 END LOOP;
 RETURN pg_catalog.jsonb_build_object('tiered',n_tier,'changed',n_changed,'up',n_up,'down',n_down,'delta',d_sum);
END;
$fn$;

-- Rücknahme der Aktivierung: Punkte und Stufen aus der Änderungshistorie wiederherstellen, Punktwerte zurücksetzen.
CREATE OR REPLACE FUNCTION league_private.deactivate_club_tiers(p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE marker text := 'Training (umgewertet nach Stundenplan)'; a record; tx public.point_transactions; s public.training_submissions; n integer := 0;
BEGIN
 IF p_actor IS NULL OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=p_actor AND p.role='admin') THEN RAISE EXCEPTION 'Rücknahme nur mit Admin-Profil'; END IF;
 UPDATE public.training_types x SET points=v.points FROM (VALUES ('Reguläres Boxtraining',50),('Techniktraining',40),('Pratzentraining',35),
   ('Sandsack / Rundenarbeit',30),('Sprint-Intervalle',40)) v(name,points) WHERE x.name=v.name;
 UPDATE public.training_types x SET is_active=false WHERE x.name='Technisches Sparring'
  AND NOT EXISTS (SELECT 1 FROM public.training_submissions ts WHERE ts.training_type_id=x.id);
 FOR a IN SELECT DISTINCT ON (au.submission_id) au.submission_id, au.old_submission, au.old_transaction
          FROM public.training_audit au WHERE au.new_transaction->>'description'=marker ORDER BY au.submission_id, au.id LOOP
  SELECT * INTO s FROM public.training_submissions x WHERE x.id=a.submission_id FOR UPDATE;
  SELECT * INTO tx FROM public.point_transactions x WHERE x.submission_id=a.submission_id FOR UPDATE;
  CONTINUE WHEN s.id IS NULL OR tx.id IS NULL;
  UPDATE public.training_submissions x SET club_tier=a.old_submission->>'club_tier' WHERE x.id=s.id;
  UPDATE public.point_transactions x SET points=(a.old_transaction->>'points')::integer, exp=(a.old_transaction->>'exp')::integer,
   description=a.old_transaction->>'description' WHERE x.id=tx.id;
  INSERT INTO public.training_audit(submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
  SELECT s.id,p_actor,pg_catalog.to_jsonb(s),pg_catalog.to_jsonb(x2),pg_catalog.to_jsonb(tx),pg_catalog.to_jsonb(y)
  FROM public.training_submissions x2, public.point_transactions y WHERE x2.id=s.id AND y.id=tx.id;
  n := n+1;
 END LOOP;
 RETURN pg_catalog.jsonb_build_object('restored',n);
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.activate_club_tiers(uuid), league_private.deactivate_club_tiers(uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.staff_open_club_session(integer), public.staff_update_gym_session(bigint,bigint,text),
 public.staff_set_training_tier(uuid,text), public.staff_training_tiers(uuid[]), public.get_club_schedule(),
 public.admin_save_club_slot(integer,integer,bigint,text,text,integer,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_open_club_session(integer), public.staff_update_gym_session(bigint,bigint,text),
 public.staff_set_training_tier(uuid,text), public.staff_training_tiers(uuid[]), public.get_club_schedule(),
 public.admin_save_club_slot(integer,integer,bigint,text,text,integer,boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
