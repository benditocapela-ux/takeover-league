-- Etappe 3 (27.10.2026, Owner-Auftrag): Wochen-Quests und Tagesquest.
-- * Fortschritt wird nur serverseitig aus BESTÄTIGTEN Trainings (bzw. angenommenen Duellen, veröffentlichtem Wochenplan) berechnet.
-- * Belohnung beim Abholen: EXP über point_transactions (points=0 → keine Monatspunkte, nur Level/Rang), category 'challenge_exp'
--   mit eigener Beschreibung 'Quest-Belohnung: …'. Coins werden pro Abholung gespeichert und ab Etappe 4 gutgeschrieben.
-- * Moderat nach Owner-Entscheid: höchstens ~175 EXP pro Woche (Wochenquests 100, Truhe 40, Tagesquest 7×5).
-- * Flag weekly_quests bleibt AUS. Bestehende Trainings, Punkte und EXP werden nicht verändert.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('league_private.group_of(uuid)') IS NULL OR to_regprocedure('league_private.require_staff()') IS NULL
    OR to_regprocedure('league_private.week_monday(date)') IS NULL OR to_regclass('public.training_plans') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: zuerst 20261028190000 (Etappe 2) anwenden';
 END IF;
 IF to_regclass('public.league_duels') IS NULL THEN RAISE EXCEPTION 'Voraussetzung fehlt: public.league_duels'; END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('weekly_quests','Wochen-Quests (Wochen- und Tagesquests mit EXP)',false)
ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.quest_definitions(
 key text PRIMARY KEY CHECK (key ~ '^[a-z][a-z0-9_]{1,30}$'),
 kind text NOT NULL CHECK (kind IN ('weekly','daily','chest')),
 title text NOT NULL CHECK (char_length(title) BETWEEN 3 AND 80),
 description text CHECK (description IS NULL OR char_length(description)<=200),
 metric text NOT NULL CHECK (metric IN ('sessions','box_sessions','technique_minutes','recovery_sessions','recovery_minutes',
   'home_minutes','jogging_km','duels','plan_pct','weekly_all')),
 target integer NOT NULL CHECK (target BETWEEN 1 AND 1000),
 group_targets jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(group_targets)='object'),
 exp integer NOT NULL CHECK (exp BETWEEN 0 AND 200),
 coins integer NOT NULL CHECK (coins BETWEEN 0 AND 1000),
 sort_order smallint NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true,
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES public.profiles(id),
 CHECK ((kind='chest') = (metric='weekly_all'))
);
INSERT INTO public.quest_definitions(key,kind,title,description,metric,target,group_targets,exp,coins,sort_order) VALUES
 ('box_sessions','weekly','{n} Boxeinheiten','Boxtraining, Technik, Pratzen, Sandsack, Schattenboxen, Sparring oder Wettkampf','box_sessions',3,
   '{"newcomer":2,"fortgeschritten":3,"wettkampf":4}',20,60,10),
 ('technique','weekly','{n} Technik-Minuten','Techniktraining zählt mit seiner Dauer','technique_minutes',90,
   '{"newcomer":60,"fortgeschritten":90,"wettkampf":120}',20,50,20),
 ('plan','weekly','Wochenplan zu {n} % erfüllen','Einheiten aus dem Plan deiner Gruppe: gleiche Trainingsart am geplanten Tag','plan_pct',80,'{}',30,80,30),
 ('recovery','weekly','{n}× Mobilität / Regeneration','Erholung gehört zum Training','recovery_sessions',1,'{}',10,30,40),
 ('duel','weekly','{n} Duell bestreiten','Ein Duell, das diese Woche angenommen wurde – egal, wer gefordert hat','duels',1,'{}',20,40,50),
 ('chest','chest','Wochentruhe','Alle verfügbaren Wochenquests der Woche abgeholt','weekly_all',1,'{}',40,200,90),
 ('d_home','daily','{n} Min. Schattenboxen oder Seilspringen','Schattenboxen / Heimtraining oder Seilspringen / Konditionszirkel','home_minutes',20,'{}',5,25,110),
 ('d_run','daily','{n} km joggen','Joggen mit Distanz eintragen','jogging_km',3,'{}',5,25,120),
 ('d_mob','daily','{n} Min. Mobilität / Regeneration','Dehnen, Mobilität oder Regeneration','recovery_minutes',15,'{}',5,25,130),
 ('d_any','daily','Heute trainieren','Irgendein Training an diesem Tag','sessions',1,'{}',5,25,140)
ON CONFLICT(key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.quest_claims(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 quest_key text NOT NULL REFERENCES public.quest_definitions(key),
 period_start date NOT NULL,
 progress numeric NOT NULL,
 target integer NOT NULL,
 exp integer NOT NULL CHECK (exp BETWEEN 0 AND 200),
 coins integer NOT NULL CHECK (coins BETWEEN 0 AND 1000),
 transaction_id uuid UNIQUE REFERENCES public.point_transactions(id),
 coins_credited_at timestamptz,
 claimed_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(profile_id, quest_key, period_start),
 CHECK ((exp=0) = (transaction_id IS NULL))
);
CREATE INDEX IF NOT EXISTS quest_claims_profile_period_idx ON public.quest_claims(profile_id, period_start DESC);

ALTER TABLE public.quest_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quest_claims ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.quest_definitions, public.quest_claims FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen (nicht aufrufbar für Clients)
CREATE OR REPLACE FUNCTION league_private.quest_target(d public.quest_definitions, p_profile uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT coalesce((d.group_targets->>((league_private.group_of(p_profile)).key))::integer, d.target)
$fn$;

CREATE OR REPLACE FUNCTION league_private.quest_title(d public.quest_definitions, p_target integer)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$ SELECT pg_catalog.replace(d.title,'{n}',p_target::text) $fn$;

-- Anteil erledigter Einheiten im veröffentlichten Plan der eigenen Gruppe (NULL = kein Plan → Quest nicht verfügbar).
CREATE OR REPLACE FUNCTION league_private.plan_pct(p_profile uuid, p_week date)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE g public.training_groups := league_private.group_of(p_profile); pl public.training_plans; total integer; done integer;
BEGIN
 IF g.id IS NULL THEN RETURN NULL; END IF;
 SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=league_private.week_monday(p_week) AND x.published_at IS NOT NULL;
 IF pl.id IS NULL THEN RETURN NULL; END IF;
 total := pg_catalog.jsonb_array_length(pl.items);
 IF total=0 THEN RETURN NULL; END IF;
 SELECT count(*) INTO done FROM pg_catalog.jsonb_array_elements(pl.items) it
 WHERE EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.boxer_id=p_profile AND s.status='approved'
   AND s.training_type_id=(it->>'type_id')::bigint AND s.training_date=pl.week_start+(it->>'day')::integer);
 RETURN floor(done*100.0/total)::integer;
END;
$fn$;

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

-- Tagesquest: feste Rotation über die aktiven Tagesquests (gleiche Quest für alle am selben Tag).
CREATE OR REPLACE FUNCTION league_private.daily_quest_key(p_day date)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT x.key FROM (SELECT d.key, (row_number() OVER (ORDER BY d.sort_order, d.key))-1 AS rn, count(*) OVER () AS c
   FROM public.quest_definitions d WHERE d.kind='daily' AND d.is_active) x
 WHERE x.rn = (((p_day - DATE '2026-01-05') % x.c) + x.c) % x.c
$fn$;

-- Zustand einer (Wochen- oder Tages-)Quest für ein Profil und einen Zeitraum.
CREATE OR REPLACE FUNCTION league_private.quest_state(p_profile uuid, d public.quest_definitions, p_from date, p_to date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE tgt integer := league_private.quest_target(d, p_profile); prog numeric; avail boolean := true; c public.quest_claims;
BEGIN
 prog := league_private.quest_progress(p_profile, d.metric, p_from, p_to);
 IF d.metric='plan_pct' AND prog IS NULL THEN avail := false; prog := 0; END IF;
 IF d.metric='duels' AND NOT league_private.flag_on('duels') THEN avail := false; END IF;
 SELECT * INTO c FROM public.quest_claims x WHERE x.profile_id=p_profile AND x.quest_key=d.key AND x.period_start=p_from;
 RETURN pg_catalog.jsonb_build_object('key',d.key,'kind',d.kind,'metric',d.metric,'title',league_private.quest_title(d,tgt),
  'description',d.description,'target',tgt,'progress',prog,'exp',coalesce(c.exp,d.exp),'coins',coalesce(c.coins,d.coins),
  'available',avail OR c.id IS NOT NULL,'done',c.id IS NOT NULL OR (avail AND prog>=tgt),'claimed',c.id IS NOT NULL,'claimed_at',c.claimed_at,
  'period_start',p_from);
END;
$fn$;

-- Alle Wochenquests + Truhe einer Woche.
CREATE OR REPLACE FUNCTION league_private.quest_week(p_profile uuid, p_week date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE ws date := league_private.week_monday(p_week); weekly jsonb; chest public.quest_definitions; cc public.quest_claims; n_av integer; n_cl integer;
BEGIN
 SELECT coalesce(pg_catalog.jsonb_agg(league_private.quest_state(p_profile,d,ws,ws+6) ORDER BY d.sort_order, d.key),'[]'::jsonb) INTO weekly
 FROM public.quest_definitions d WHERE d.kind='weekly' AND (d.is_active OR EXISTS (SELECT 1 FROM public.quest_claims x
   WHERE x.profile_id=p_profile AND x.quest_key=d.key AND x.period_start=ws));
 SELECT count(*) FILTER (WHERE (q->>'available')::boolean), count(*) FILTER (WHERE (q->>'claimed')::boolean)
 INTO n_av, n_cl FROM pg_catalog.jsonb_array_elements(weekly) q;
 SELECT * INTO chest FROM public.quest_definitions d WHERE d.kind='chest' ORDER BY d.key LIMIT 1;
 IF chest.key IS NOT NULL THEN
  SELECT * INTO cc FROM public.quest_claims x WHERE x.profile_id=p_profile AND x.quest_key=chest.key AND x.period_start=ws;
 END IF;
 RETURN pg_catalog.jsonb_build_object('week_start',ws,'weekly',weekly,
  'chest',CASE WHEN chest.key IS NULL OR (NOT chest.is_active AND cc.id IS NULL) THEN NULL ELSE pg_catalog.jsonb_build_object(
    'key',chest.key,'kind','chest','title',chest.title,'description',chest.description,'target',n_av,'progress',n_cl,
    'exp',coalesce(cc.exp,chest.exp),'coins',coalesce(cc.coins,chest.coins),'available',n_av>0 OR cc.id IS NOT NULL,
    'done',cc.id IS NOT NULL OR (n_av>0 AND n_cl>=n_av),'claimed',cc.id IS NOT NULL,'claimed_at',cc.claimed_at,'period_start',ws) END);
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.quest_target(public.quest_definitions,uuid), league_private.quest_title(public.quest_definitions,integer),
 league_private.plan_pct(uuid,date), league_private.quest_progress(uuid,text,date,date), league_private.daily_quest_key(date),
 league_private.quest_state(uuid,public.quest_definitions,date,date), league_private.quest_week(uuid,date)
 FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPCs
CREATE OR REPLACE FUNCTION public.get_my_quests(p_week_start date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := league_private.zurich_today(); cur date; ws date;
 w jsonb; days jsonb; on_ boolean := league_private.flag_on('weekly_quests'); can boolean;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT on_ AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 cur := league_private.week_monday(today);
 ws := league_private.week_monday(coalesce(p_week_start,today));
 IF ws > cur OR ws < cur-56 THEN RAISE EXCEPTION 'Quests gibt es nur für die letzten 8 Wochen' USING ERRCODE='22023'; END IF;
 can := on_ AND me.role IN ('boxer','coach') AND ws >= cur-7;
 w := league_private.quest_week(me.id, ws);
 SELECT coalesce(pg_catalog.jsonb_agg(CASE WHEN k.q IS NULL THEN pg_catalog.jsonb_build_object('period_start',x.day,'key',NULL)
     ELSE league_private.quest_state(me.id,k.q,x.day,x.day) END ORDER BY x.day),'[]'::jsonb)
 INTO days
 FROM (SELECT (ws+i) AS day FROM pg_catalog.generate_series(0,6) i WHERE ws+i<=today) x
 LEFT JOIN LATERAL (SELECT d AS q FROM public.quest_definitions d
   WHERE d.key=coalesce((SELECT c.quest_key FROM public.quest_claims c JOIN public.quest_definitions q ON q.key=c.quest_key
      WHERE c.profile_id=me.id AND c.period_start=x.day AND q.kind='daily' LIMIT 1), league_private.daily_quest_key(x.day))) k ON true;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT on_,'can_claim',can,'today',today,'week_start',ws,'current_week',cur,
  'claim_from',cur-7,'group',league_private.group_json(league_private.group_of(me.id)),
  'weekly',w->'weekly','chest',w->'chest','daily',days,
  'exp_week',(SELECT coalesce(sum(c.exp),0) FROM public.quest_claims c WHERE c.profile_id=me.id AND c.period_start BETWEEN ws AND ws+6),
  'coins_pending',(SELECT coalesce(sum(c.coins),0) FROM public.quest_claims c WHERE c.profile_id=me.id AND c.coins_credited_at IS NULL));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.claim_quest(p_quest_key text, p_period date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := league_private.zurich_today(); d public.quest_definitions;
 per date; st jsonb; tx uuid; tgt integer;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('boxer','coach') THEN RAISE EXCEPTION 'Quests holen Boxer mit ihrem eigenen Konto ab' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('weekly_quests') THEN RAISE EXCEPTION 'Die Wochen-Quests sind noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_period IS NULL THEN RAISE EXCEPTION 'Bitte einen Zeitraum angeben' USING ERRCODE='22023'; END IF;
 SELECT * INTO d FROM public.quest_definitions x WHERE x.key=p_quest_key AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte oder inaktive Quest' USING ERRCODE='22023'; END IF;
 IF d.kind='daily' THEN
  per := p_period;
  IF league_private.daily_quest_key(per) IS DISTINCT FROM d.key THEN RAISE EXCEPTION 'Das war an diesem Tag nicht die Tagesquest' USING ERRCODE='22023'; END IF;
 ELSE
  per := league_private.week_monday(p_period);
 END IF;
 IF per > today THEN RAISE EXCEPTION 'Dieser Zeitraum hat noch nicht begonnen' USING ERRCODE='22023'; END IF;
 IF per < league_private.week_monday(today)-7 THEN RAISE EXCEPTION 'Diese Quest ist abgelaufen' USING ERRCODE='22023'; END IF;
 -- Abholungen eines Profils nacheinander (Truhe zählt die anderen Abholungen).
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('quest_claim:'||me.id::text));
 IF EXISTS (SELECT 1 FROM public.quest_claims c WHERE c.profile_id=me.id AND c.quest_key=d.key AND c.period_start=per) THEN
  RAISE EXCEPTION 'Diese Belohnung hast du schon abgeholt' USING ERRCODE='23505';
 END IF;
 IF d.kind='chest' THEN st := league_private.quest_week(me.id, per)->'chest';
 ELSIF d.kind='daily' THEN st := league_private.quest_state(me.id, d, per, per);
 ELSE st := league_private.quest_state(me.id, d, per, per+6); END IF;
 IF st IS NULL OR NOT (st->>'available')::boolean THEN RAISE EXCEPTION 'Diese Quest ist diese Woche nicht verfügbar' USING ERRCODE='22023'; END IF;
 IF NOT (st->>'done')::boolean THEN RAISE EXCEPTION 'Diese Quest ist noch nicht erfüllt' USING ERRCODE='22023'; END IF;
 tgt := (st->>'target')::integer;
 IF d.exp>0 THEN
  INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
  VALUES (me.id,NULL,0,d.exp,'challenge_exp','Quest-Belohnung: '||d.key||' '||per::text,today,me.id) RETURNING id INTO tx;
 END IF;
 INSERT INTO public.quest_claims(profile_id,quest_key,period_start,progress,target,exp,coins,transaction_id)
 VALUES (me.id,d.key,per,(st->>'progress')::numeric,tgt,d.exp,d.coins,tx);
 RETURN pg_catalog.jsonb_build_object('key',d.key,'title',st->>'title','period_start',per,'exp',d.exp,'coins',d.coins);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_quest_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); ws date := league_private.week_monday(league_private.zurich_today());
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,
   'group',league_private.group_json(league_private.group_of(p.id)),
   'available',(SELECT count(*) FROM pg_catalog.jsonb_array_elements(w.v->'weekly') q WHERE (q->>'available')::boolean),
   'done',(SELECT count(*) FROM pg_catalog.jsonb_array_elements(w.v->'weekly') q WHERE (q->>'done')::boolean),
   'claimed',(SELECT count(*) FROM pg_catalog.jsonb_array_elements(w.v->'weekly') q WHERE (q->>'claimed')::boolean),
   'chest',coalesce((w.v->'chest'->>'claimed')::boolean,false),
   'exp_week',(SELECT coalesce(sum(c.exp),0) FROM public.quest_claims c WHERE c.profile_id=p.id AND c.period_start BETWEEN ws AND ws+6))
   ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p CROSS JOIN LATERAL (SELECT league_private.quest_week(p.id, ws) AS v) w
  WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_list_quests()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 RETURN pg_catalog.jsonb_build_object('today_daily',league_private.daily_quest_key(league_private.zurich_today()),
  'quests',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('key',d.key,'kind',d.kind,'title',d.title,'description',d.description,
   'metric',d.metric,'target',d.target,'group_targets',d.group_targets,'exp',d.exp,'coins',d.coins,'is_active',d.is_active,
   'updated_at',d.updated_at,'claims',(SELECT count(*) FROM public.quest_claims c WHERE c.quest_key=d.key)) ORDER BY d.sort_order, d.key)
  FROM public.quest_definitions d),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_update_quest(p_quest_key text, p_target integer, p_exp integer, p_coins integer, p_is_active boolean, p_group_targets jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); d public.quest_definitions; max_exp integer; max_tgt integer; k text; v jsonb; gt jsonb := coalesce(p_group_targets,'{}'::jsonb);
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin ändert Quests' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.quest_definitions x WHERE x.key=p_quest_key FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Quest' USING ERRCODE='22023'; END IF;
 max_exp := CASE d.kind WHEN 'weekly' THEN 100 WHEN 'chest' THEN 200 ELSE 50 END;
 IF p_exp IS NULL OR p_exp NOT BETWEEN 0 AND max_exp THEN RAISE EXCEPTION 'EXP zwischen 0 und %', max_exp USING ERRCODE='22023'; END IF;
 IF p_coins IS NULL OR p_coins NOT BETWEEN 0 AND 1000 THEN RAISE EXCEPTION 'Coins zwischen 0 und 1000' USING ERRCODE='22023'; END IF;
 IF p_is_active IS NULL THEN RAISE EXCEPTION 'Bitte aktiv oder inaktiv wählen' USING ERRCODE='22023'; END IF;
 IF d.kind='chest' THEN p_target := 1; gt := '{}'::jsonb; END IF;
 max_tgt := (CASE WHEN d.metric='plan_pct' THEN 100 ELSE 1000 END);
 IF p_target IS NULL OR p_target NOT BETWEEN 1 AND max_tgt THEN
  RAISE EXCEPTION 'Ungültiges Ziel' USING ERRCODE='22023';
 END IF;
 IF pg_catalog.jsonb_typeof(gt)<>'object' THEN RAISE EXCEPTION 'Gruppenziele ungültig' USING ERRCODE='22023'; END IF;
 FOR k, v IN SELECT * FROM pg_catalog.jsonb_each(gt) LOOP
  IF NOT EXISTS (SELECT 1 FROM public.training_groups g WHERE g.key=k) OR pg_catalog.jsonb_typeof(v)<>'number'
     OR (v::text)::numeric<>trunc((v::text)::numeric) OR (v::text)::numeric NOT BETWEEN 1 AND max_tgt THEN
   RAISE EXCEPTION 'Gruppenziel für % ungültig', k USING ERRCODE='22023';
  END IF;
 END LOOP;
 IF d.kind='daily' AND NOT p_is_active AND NOT EXISTS (SELECT 1 FROM public.quest_definitions x WHERE x.kind='daily' AND x.is_active AND x.key<>d.key) THEN
  RAISE EXCEPTION 'Mindestens eine Tagesquest muss aktiv bleiben' USING ERRCODE='22023';
 END IF;
 UPDATE public.quest_definitions x SET target=p_target, exp=p_exp, coins=p_coins, is_active=p_is_active, group_targets=gt,
  updated_at=now(), updated_by=me.id WHERE x.key=d.key RETURNING * INTO d;
 RETURN pg_catalog.jsonb_build_object('key',d.key,'target',d.target,'exp',d.exp,'coins',d.coins,'is_active',d.is_active,'group_targets',d.group_targets);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_quests(date), public.claim_quest(text,date), public.staff_quest_overview(),
 public.admin_list_quests(), public.admin_update_quest(text,integer,integer,integer,boolean,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_quests(date), public.claim_quest(text,date), public.staff_quest_overview(),
 public.admin_list_quests(), public.admin_update_quest(text,integer,integer,integer,boolean,jsonb) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
