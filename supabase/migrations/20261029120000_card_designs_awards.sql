-- Etappe 7d (28.10.2026, Owner-Auftrag): Spielerkarten-Designs und Auszeichnungen Card of the Week / Month / Player of the Year.
-- * Designs: «Klassisch» für alle, sechs Designs schalten sich mit dem Rang frei (E bis S), drei gibt es im Kampfgeist-Shop
--   (Coins, nur wenn der Shop freigeschaltet ist), drei nur als Auszeichnung (Card of the Week, Card of the Month, Player of the Year).
-- * Auszeichnungen: Das System schlägt vor (meiste EXP aus bestätigten Trainings in der Woche / im Monat / im Jahr),
--   ein Trainer oder der Admin bestätigt oder wählt jemand anderen. Eine Auszeichnung pro Art und Zeitraum; zurücknehmen statt löschen.
--   Wer ausgezeichnet wurde, behält das Design dauerhaft (solange die Auszeichnung nicht zurückgenommen ist) und bekommt eine Benachrichtigung.
-- * Neues Feature-Flag card_designs (AUS). Admin und Trainer können vorab testen.
-- Bestehende Daten (Punkte, EXP, Coins, Trainings) bleiben unverändert.
BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.active_viewer()') IS NULL OR to_regprocedure('league_private.flag_on(text)') IS NULL
    OR to_regprocedure('league_private.kg_exp(uuid)') IS NULL OR to_regprocedure('league_private.kg_balance(uuid)') IS NULL
    OR to_regprocedure('league_private.kg_sync(uuid)') IS NULL OR to_regclass('public.boxer_notifications') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Kampfgeist (20261028210000), Benachrichtigungen';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('card_designs','Karten-Designs & Auszeichnungen',false) ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.card_designs(
 key text PRIMARY KEY CHECK (key ~ '^[a-z][a-z0-9_]{1,30}$'),
 name text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 40),
 description text CHECK (description IS NULL OR char_length(description)<=160),
 unlock text NOT NULL CHECK (unlock IN ('start','rank','shop','award')),
 min_rank text CHECK (min_rank IS NULL OR min_rank IN ('F','E','D','C','B','A','S')),
 price integer CHECK (price IS NULL OR price BETWEEN 10 AND 20000),
 award_kind text CHECK (award_kind IS NULL OR award_kind IN ('cotw','cotm','poty')),
 design jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(design)='object'),
 sort_order integer NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true,
 CHECK ((unlock='shop')=(price IS NOT NULL)), CHECK ((unlock='rank')=(min_rank IS NOT NULL)), CHECK ((unlock='award')=(award_kind IS NOT NULL))
);
INSERT INTO public.card_designs(key,name,description,unlock,min_rank,price,award_kind,design,sort_order) VALUES
 ('classic','Klassisch','Bronze, Silber, Gold oder Elite – je nach Gesamtwertung.','start',NULL,NULL,NULL,'{"tier":true}',10),
 ('carbon','Carbon','Dunkles Carbon mit silbernen Kanten.','rank','E',NULL,NULL,'{"a":"#3a3f4b","b":"#14171d","ink":"#e8ecf2","edge":"#9aa3b0","pattern":"carbon"}',20),
 ('ocean','Ozean','Tiefes Blau wie ein Bergsee.','rank','D',NULL,NULL,'{"a":"#5fc3ff","b":"#0d3a6e","ink":"#f2f8ff","edge":"#bfe6ff","pattern":"waves"}',30),
 ('ember','Glut','Rot-orange wie ein Feuer nach der letzten Runde.','rank','C',NULL,NULL,'{"a":"#ffb347","b":"#a3220f","ink":"#fff4e6","edge":"#ffd27a","pattern":"sparks"}',40),
 ('aurora','Polarlicht','Grün-violettes Nordlicht.','rank','B',NULL,NULL,'{"a":"#7cf5c8","b":"#4b2a8c","ink":"#f4fff9","edge":"#c7ffe9","pattern":"aurora"}',50),
 ('royal','Königlich','Purpur mit Goldrand.','rank','A',NULL,NULL,'{"a":"#b678ff","b":"#2a0f52","ink":"#fff7e0","edge":"#f2c14e","pattern":"crown"}',60),
 ('legend','Legende','Für Rang S: Schwarz mit leuchtendem Gold.','rank','S',NULL,NULL,'{"a":"#2b2410","b":"#050505","ink":"#f2c14e","edge":"#f2c14e","pattern":"rays","glow":true}',70),
 ('neon','Neon','Leuchtend wie eine Arena bei Nacht.','shop',NULL,400,NULL,'{"a":"#ff3ea5","b":"#1b0a3a","ink":"#ffffff","edge":"#3ef0ff","pattern":"grid"}',80),
 ('sakura','Kirschblüte','Rosa Blüten für leichte Füsse.','shop',NULL,600,NULL,'{"a":"#ffd1e3","b":"#c2577f","ink":"#3a0f22","edge":"#fff0f6","pattern":"petals"}',90),
 ('thunder','Donner','Gewitterblau mit Blitzen.','shop',NULL,900,NULL,'{"a":"#7fa7ff","b":"#141a3d","ink":"#f5f8ff","edge":"#ffe066","pattern":"bolts"}',100),
 ('cotw','Card of the Week','Nur für die Card of the Week.','award',NULL,NULL,'cotw','{"a":"#7be3a0","b":"#0f3b2a","ink":"#f2fff7","edge":"#f2c14e","pattern":"rays","badge":"COTW"}',110),
 ('cotm','Card of the Month','Nur für die Card of the Month.','award',NULL,NULL,'cotm','{"a":"#ff9f5a","b":"#3d1206","ink":"#fff3e8","edge":"#f2c14e","pattern":"rays","badge":"COTM","glow":true}',120),
 ('poty','Player of the Year','Nur für den Player of the Year.','award',NULL,NULL,'poty','{"a":"#fff0bf","b":"#0a0a0a","ink":"#f2c14e","edge":"#ffffff","pattern":"diamond","badge":"POTY","glow":true}',130)
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.card_design_purchases(
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 design_key text NOT NULL REFERENCES public.card_designs(key),
 price_paid integer NOT NULL CHECK (price_paid>=0),
 ledger_id bigint UNIQUE REFERENCES public.kg_ledger(id),
 acquired_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(profile_id, design_key)
);
CREATE TABLE IF NOT EXISTS public.card_design_equipped(
 profile_id uuid PRIMARY KEY REFERENCES public.profiles(id),
 design_key text NOT NULL REFERENCES public.card_designs(key),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.card_awards(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 kind text NOT NULL CHECK (kind IN ('cotw','cotm','poty')),
 period_start date NOT NULL,
 period_end date NOT NULL CHECK (period_end>=period_start),
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 exp_in_period integer NOT NULL DEFAULT 0,
 note text CHECK (note IS NULL OR char_length(note)<=300),
 awarded_by uuid NOT NULL REFERENCES public.profiles(id),
 awarded_at timestamptz NOT NULL DEFAULT now(),
 revoked_at timestamptz,
 revoked_by uuid REFERENCES public.profiles(id),
 revoke_reason text CHECK (revoke_reason IS NULL OR char_length(revoke_reason)<=300)
);
CREATE UNIQUE INDEX IF NOT EXISTS card_awards_one_active ON public.card_awards(kind, period_start) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS card_awards_profile_idx ON public.card_awards(profile_id) WHERE revoked_at IS NULL;
ALTER TABLE public.card_designs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_design_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_design_equipped ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_awards ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.card_designs, public.card_design_purchases, public.card_design_equipped, public.card_awards FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen
CREATE OR REPLACE FUNCTION league_private.card_period(p_kind text, p_day date)
RETURNS daterange LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT CASE p_kind
  WHEN 'cotw' THEN pg_catalog.daterange((p_day - (extract(isodow FROM p_day)::integer-1)), (p_day - (extract(isodow FROM p_day)::integer-1))+6, '[]')
  WHEN 'cotm' THEN pg_catalog.daterange(pg_catalog.date_trunc('month',p_day)::date, (pg_catalog.date_trunc('month',p_day)+interval '1 month -1 day')::date, '[]')
  WHEN 'poty' THEN pg_catalog.daterange(pg_catalog.date_trunc('year',p_day)::date, (pg_catalog.date_trunc('year',p_day)+interval '1 year -1 day')::date, '[]')
 END
$fn$;

CREATE OR REPLACE FUNCTION league_private.card_rank_idx(p uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT league_private.kg_rank_idx(league_private.kg_level(league_private.kg_exp(p)))
$fn$;

-- Verfügbar: Klassisch immer; Rang-Designs ab Rang; Shop-Designs nach Kauf; Auszeichnungs-Designs mit aktiver Auszeichnung.
CREATE OR REPLACE FUNCTION league_private.card_design_available(p uuid, d public.card_designs)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT d.is_active AND CASE d.unlock
  WHEN 'start' THEN true
  WHEN 'rank' THEN league_private.card_rank_idx(p) >= pg_catalog.array_position(ARRAY['F','E','D','C','B','A','S'],d.min_rank)-1
  WHEN 'shop' THEN EXISTS (SELECT 1 FROM public.card_design_purchases x WHERE x.profile_id=p AND x.design_key=d.key)
  WHEN 'award' THEN EXISTS (SELECT 1 FROM public.card_awards a WHERE a.profile_id=p AND a.kind=d.award_kind AND a.revoked_at IS NULL)
  ELSE false END
$fn$;

-- Angezeigtes Design: ausgewähltes (falls weiterhin verfügbar), sonst Klassisch.
CREATE OR REPLACE FUNCTION league_private.card_look(p uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE d public.card_designs;
BEGIN
 SELECT x.* INTO d FROM public.card_design_equipped e JOIN public.card_designs x ON x.key=e.design_key WHERE e.profile_id=p;
 IF d.key IS NULL OR NOT league_private.card_design_available(p,d) THEN SELECT * INTO d FROM public.card_designs WHERE key='classic'; END IF;
 RETURN pg_catalog.jsonb_build_object('key',d.key,'name',d.name,'design',d.design,
  'awards',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('kind',a.kind,'period_start',a.period_start) ORDER BY a.period_start DESC)
    FROM public.card_awards a WHERE a.profile_id=p AND a.revoked_at IS NULL),'[]'::jsonb));
END;
$fn$;

-- Vorschläge: meiste EXP aus bestätigten Trainings im Zeitraum (aktive, nicht archivierte Boxer und Trainer), Top 3.
CREATE OR REPLACE FUNCTION league_private.card_candidates(p_from date, p_to date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('profile_id',x.id,'display_name',x.display_name,'exp',x.exp,'trainings',x.n) ORDER BY x.exp DESC, x.n DESC, x.display_name),'[]'::jsonb)
 FROM (SELECT p.id, p.display_name, sum(t.exp)::integer AS exp, count(*) AS n
       FROM public.point_transactions t JOIN public.training_submissions s ON s.id=t.submission_id AND s.status='approved'
       JOIN public.profiles p ON p.id=t.boxer_id AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')
       WHERE t.effective_date BETWEEN p_from AND p_to GROUP BY p.id, p.display_name HAVING sum(t.exp)>0
       ORDER BY sum(t.exp) DESC, count(*) DESC, p.display_name LIMIT 3) x
$fn$;

CREATE OR REPLACE FUNCTION league_private.card_award_json(a public.card_awards)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object('id',a.id,'kind',a.kind,'period_start',a.period_start,'period_end',a.period_end,
  'display_name',(SELECT p.display_name FROM public.profiles p WHERE p.id=a.profile_id),'exp',a.exp_in_period,'note',a.note,
  'awarded_at',a.awarded_at,'awarded_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=a.awarded_by),
  'revoked',a.revoked_at IS NOT NULL)
$fn$;

REVOKE ALL ON FUNCTION league_private.card_period(text,date), league_private.card_rank_idx(uuid),
 league_private.card_design_available(uuid,public.card_designs), league_private.card_look(uuid),
 league_private.card_candidates(date,date), league_private.card_award_json(public.card_awards) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Boxer: eigene Designs (verfügbar / gesperrt mit Grund), ausgewähltes Design, Coins.
CREATE OR REPLACE FUNCTION public.get_my_card_designs()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); ri integer; shop boolean;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('card_designs') AND me.role NOT IN ('admin','coach') THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 ri := league_private.card_rank_idx(me.id); shop := league_private.flag_on('kampfgeist_shop') OR me.role='admin';
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT league_private.flag_on('card_designs'),'display_name',me.display_name,
  'rank',(ARRAY['F','E','D','C','B','A','S'])[ri+1],'shop',shop,'coins',CASE WHEN shop THEN league_private.kg_balance(me.id) END,
  'look',league_private.card_look(me.id),
  'designs',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('key',d.key,'name',d.name,'description',d.description,'unlock',d.unlock,
     'min_rank',d.min_rank,'price',d.price,'award_kind',d.award_kind,'design',d.design,
     'available',league_private.card_design_available(me.id,d)) ORDER BY d.sort_order, d.key)
   FROM public.card_designs d WHERE d.is_active));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.equip_card_design(p_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); d public.card_designs;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('card_designs') AND me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Karten-Designs sind noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.card_designs x WHERE x.key=p_key AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Dieses Design gibt es nicht' USING ERRCODE='22023'; END IF;
 IF NOT league_private.card_design_available(me.id,d) THEN RAISE EXCEPTION 'Dieses Design ist für dich noch gesperrt' USING ERRCODE='42501'; END IF;
 INSERT INTO public.card_design_equipped(profile_id,design_key) VALUES (me.id,d.key)
 ON CONFLICT (profile_id) DO UPDATE SET design_key=EXCLUDED.design_key, updated_at=now();
 RETURN league_private.card_look(me.id);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.buy_card_design(p_key text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); d public.card_designs; bal integer; lid bigint;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT (league_private.flag_on('card_designs') OR me.role='admin') OR NOT (league_private.flag_on('kampfgeist_shop') OR me.role='admin') THEN
  RAISE EXCEPTION 'Der Shop ist noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 SELECT * INTO d FROM public.card_designs x WHERE x.key=p_key AND x.is_active;
 IF NOT FOUND OR d.unlock<>'shop' THEN RAISE EXCEPTION 'Dieses Design gibt es nicht im Shop' USING ERRCODE='22023'; END IF;
 PERFORM league_private.kg_sync(me.id);  -- nimmt auch die Sperre für dieses Konto
 IF EXISTS (SELECT 1 FROM public.card_design_purchases x WHERE x.profile_id=me.id AND x.design_key=d.key) THEN
  RAISE EXCEPTION 'Dieses Design hast du schon' USING ERRCODE='23505';
 END IF;
 bal := league_private.kg_balance(me.id);
 IF bal<d.price THEN RAISE EXCEPTION 'Zu wenig Coins: dir fehlen noch %', d.price-bal USING ERRCODE='22023'; END IF;
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note,created_by)
 VALUES (me.id,-d.price,'purchase','card:'||d.key,'Karten-Design: '||d.name,me.id) RETURNING id INTO lid;
 INSERT INTO public.card_design_purchases(profile_id,design_key,price_paid,ledger_id) VALUES (me.id,d.key,d.price,lid);
 RETURN pg_catalog.jsonb_build_object('key',d.key,'name',d.name,'price',d.price,'balance',bal-d.price);
END;
$fn$;

-- Karten-Looks anderer (Profil, Vergleich, Podium): nur angemeldete Mitglieder, nur sichtbare Profile (Trainer sehen alle).
CREATE OR REPLACE FUNCTION public.get_card_looks(p_display_names text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); staff boolean;
BEGIN
 IF me.id IS NULL THEN RETURN '{}'::jsonb; END IF;
 IF NOT league_private.flag_on('card_designs') AND me.role NOT IN ('admin','coach') THEN RETURN '{}'::jsonb; END IF;
 IF coalesce(pg_catalog.cardinality(p_display_names),0)>50 THEN RAISE EXCEPTION 'Höchstens 50 Namen auf einmal' USING ERRCODE='22023'; END IF;
 staff := me.role IN ('admin','coach');
 RETURN coalesce((SELECT pg_catalog.jsonb_object_agg(p.display_name, league_private.card_look(p.id))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')
   AND pg_catalog.lower(p.display_name) IN (SELECT pg_catalog.lower(pg_catalog.btrim(n)) FROM pg_catalog.unnest(p_display_names) n)
   AND (p.id=me.id OR staff OR p.is_listed IS TRUE)
   AND (SELECT count(*) FROM public.profiles q WHERE pg_catalog.lower(q.display_name)=pg_catalog.lower(p.display_name) AND q.is_active AND q.archived_at IS NULL)=1),'{}'::jsonb);
END;
$fn$;

-- Aktuelle und letzte Auszeichnungen (für Podium und Karten-Seite).
CREATE OR REPLACE FUNCTION public.get_card_awards()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 IF NOT league_private.flag_on('card_designs') AND me.role NOT IN ('admin','coach') THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT league_private.flag_on('card_designs'),
  'latest',coalesce((SELECT pg_catalog.jsonb_object_agg(k, (SELECT league_private.card_award_json(a) || pg_catalog.jsonb_build_object('look',league_private.card_look(a.profile_id))
     FROM public.card_awards a JOIN public.profiles p ON p.id=a.profile_id
     WHERE a.kind=k AND a.revoked_at IS NULL AND (p.is_listed IS TRUE OR p.id=me.id OR me.role IN ('admin','coach'))
     ORDER BY a.period_start DESC LIMIT 1)) FROM pg_catalog.unnest(ARRAY['cotw','cotm','poty']) k),'{}'::jsonb),
  'history',coalesce((SELECT pg_catalog.jsonb_agg(league_private.card_award_json(x) ORDER BY x.period_start DESC, x.id DESC) FROM (
     SELECT a.* FROM public.card_awards a JOIN public.profiles p ON p.id=a.profile_id
     WHERE a.revoked_at IS NULL AND (p.is_listed IS TRUE OR p.id=me.id OR me.role IN ('admin','coach'))
     ORDER BY a.period_start DESC, a.id DESC LIMIT 24) x),'[]'::jsonb));
END;
$fn$;

-- Trainer/Admin: Vorschläge für die letzte abgeschlossene Woche / den letzten Monat / das letzte Jahr und die laufenden Zeiträume.
CREATE OR REPLACE FUNCTION public.staff_card_award_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := (now() AT TIME ZONE 'Europe/Zurich')::date; res jsonb := '[]'::jsonb;
 k text; r daterange; prev daterange;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für Trainer und Admins' USING ERRCODE='42501'; END IF;
 FOREACH k IN ARRAY ARRAY['cotw','cotm','poty'] LOOP
  r := league_private.card_period(k,today);
  prev := league_private.card_period(k,lower(r)-1);
  res := res || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('kind',k,'periods',pg_catalog.jsonb_build_array(
   pg_catalog.jsonb_build_object('start',lower(prev),'end',upper(prev)-1,'completed',true,'candidates',league_private.card_candidates(lower(prev),upper(prev)-1),
    'award',(SELECT league_private.card_award_json(a) FROM public.card_awards a WHERE a.kind=k AND a.period_start=lower(prev) AND a.revoked_at IS NULL)),
   pg_catalog.jsonb_build_object('start',lower(r),'end',upper(r)-1,'completed',false,'candidates',league_private.card_candidates(lower(r),LEAST(upper(r)-1,today)),
    'award',(SELECT league_private.card_award_json(a) FROM public.card_awards a WHERE a.kind=k AND a.period_start=lower(r) AND a.revoked_at IS NULL)))));
 END LOOP;
 RETURN pg_catalog.jsonb_build_object('today',today,'kinds',res,
  'boxers',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name) ORDER BY pg_catalog.lower(p.display_name))
   FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')));
END;
$fn$;

-- Trainer/Admin bestätigt (Vorschlag oder eigene Wahl). Laufende Zeiträume erst nach dem Ende; nicht sich selbst.
CREATE OR REPLACE FUNCTION public.staff_confirm_card_award(p_kind text, p_period_start date, p_profile_id uuid, p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles; today date := (now() AT TIME ZONE 'Europe/Zurich')::date;
 r daterange; a public.card_awards; v integer; n text; label text;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur Trainer und Admins vergeben Auszeichnungen' USING ERRCODE='42501'; END IF;
 IF coalesce(p_kind,'') NOT IN ('cotw','cotm','poty') THEN RAISE EXCEPTION 'Unbekannte Auszeichnung' USING ERRCODE='22023'; END IF;
 IF p_period_start IS NULL THEN RAISE EXCEPTION 'Bitte einen Zeitraum wählen' USING ERRCODE='22023'; END IF;
 r := league_private.card_period(p_kind,p_period_start);
 IF lower(r)<>p_period_start THEN RAISE EXCEPTION 'Der Zeitraum muss am Wochen-, Monats- oder Jahresanfang beginnen' USING ERRCODE='22023'; END IF;
 IF upper(r)-1 >= today THEN RAISE EXCEPTION 'Erst nach Ende des Zeitraums vergeben (ab %)', to_char(upper(r),'DD.MM.YYYY') USING ERRCODE='22023'; END IF;
 IF lower(r) < today - (CASE p_kind WHEN 'cotw' THEN 70 WHEN 'cotm' THEN 400 ELSE 800 END) THEN RAISE EXCEPTION 'Dieser Zeitraum liegt zu weit zurück' USING ERRCODE='22023'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_profile_id AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023'; END IF;
 IF t.id=me.id THEN RAISE EXCEPTION 'Sich selbst auszeichnen geht nicht – das macht ein anderer Trainer' USING ERRCODE='42501'; END IF;
 n := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF n IS NOT NULL AND char_length(n)>300 THEN RAISE EXCEPTION 'Begründung höchstens 300 Zeichen' USING ERRCODE='22023'; END IF;
 IF EXISTS (SELECT 1 FROM public.card_awards x WHERE x.kind=p_kind AND x.period_start=lower(r) AND x.revoked_at IS NULL) THEN
  RAISE EXCEPTION 'Für diesen Zeitraum gibt es schon eine Auszeichnung – zuerst zurücknehmen' USING ERRCODE='23505';
 END IF;
 SELECT coalesce(sum(tx.exp),0)::integer INTO v FROM public.point_transactions tx JOIN public.training_submissions s ON s.id=tx.submission_id AND s.status='approved'
 WHERE tx.boxer_id=t.id AND tx.effective_date BETWEEN lower(r) AND upper(r)-1;
 INSERT INTO public.card_awards(kind,period_start,period_end,profile_id,exp_in_period,note,awarded_by)
 VALUES (p_kind,lower(r),upper(r)-1,t.id,v,n,me.id) RETURNING * INTO a;
 label := CASE p_kind WHEN 'cotw' THEN 'Card of the Week' WHEN 'cotm' THEN 'Card of the Month' ELSE 'Player of the Year' END;
 INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
 VALUES (t.id,'achievement',label||'!','Glückwunsch! Du bist '||label||' ('||to_char(lower(r),'DD.MM.YYYY')||' – '||to_char(upper(r)-1,'DD.MM.YYYY')||'). Dein neues Karten-Design ist freigeschaltet.'||coalesce(' «'||n||'»',''),'/karten.html');
 RETURN league_private.card_award_json(a);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_revoke_card_award(p_award_id bigint, p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); a public.card_awards; rs text;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur Trainer und Admins' USING ERRCODE='42501'; END IF;
 rs := NULLIF(pg_catalog.btrim(coalesce(p_reason,'')),'');
 IF rs IS NULL OR char_length(rs)>300 THEN RAISE EXCEPTION 'Bitte kurz begründen (höchstens 300 Zeichen)' USING ERRCODE='22023'; END IF;
 SELECT * INTO a FROM public.card_awards x WHERE x.id=p_award_id FOR UPDATE;
 IF NOT FOUND OR a.revoked_at IS NOT NULL THEN RAISE EXCEPTION 'Auszeichnung nicht gefunden oder schon zurückgenommen' USING ERRCODE='22023'; END IF;
 IF me.role<>'admin' AND a.awarded_by<>me.id THEN RAISE EXCEPTION 'Nur wer vergeben hat oder der Admin nimmt zurück' USING ERRCODE='42501'; END IF;
 UPDATE public.card_awards x SET revoked_at=now(), revoked_by=me.id, revoke_reason=rs WHERE x.id=a.id RETURNING * INTO a;
 RETURN league_private.card_award_json(a);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_card_designs(), public.equip_card_design(text), public.buy_card_design(text), public.get_card_looks(text[]),
 public.get_card_awards(), public.staff_card_award_overview(), public.staff_confirm_card_award(text,date,uuid,text),
 public.staff_revoke_card_award(bigint,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_card_designs(), public.equip_card_design(text), public.buy_card_design(text), public.get_card_looks(text[]),
 public.get_card_awards(), public.staff_card_award_overview(), public.staff_confirm_card_award(text,date,uuid,text),
 public.staff_revoke_card_award(bigint,text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
