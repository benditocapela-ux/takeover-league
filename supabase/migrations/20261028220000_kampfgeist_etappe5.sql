-- Etappe 5 (28.10.2026, Owner-Auftrag): Emotes (nur bei Duell und Podium), Einlauf, Kampfpfad pro Monat.
-- Owner-Entscheide: Emotes zunächst nur bei Duell und Podium sichtbar; Kampfpfad läuft jeweils pro Kalendermonat;
-- Fortschritt aus bestätigten Trainings, abgeholten Quests und Duellen.
-- * Emotes sind vorgegebene, positive Texte (kein Freitext). Nur Duell-Teilnehmende senden in ihr eigenes Duell;
--   aufs Podium (Top 3 des Monats) kann jedes angemeldete Mitglied einmal pro Tag und Person reagieren. Sichtbar nur für
--   Angemeldete; Coaches/Admin können Emotes ausblenden, der Admin kann Emotes eines Kontos stummschalten.
-- * Kampfpfad: 30 Stufen pro Monat, Punkte werden live aus vorhandenen Daten berechnet (keine Änderung an Trainings, Quests,
--   Duellen, Punkten oder EXP). Belohnungen: Coins (Coin-Buch, Grund 'pass') und 5 Kampfpfad-Items; wer ein Item schon hat,
--   bekommt Ersatz-Coins. Abholen im laufenden und im Vormonat.
-- * Flag bleibt: alles läuft unter dem bestehenden Flag kampfgeist_shop (aus). Ohne Flag nur Admin-Vorschau (nur lesen).
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('league_private.kg_sync(uuid)') IS NULL OR to_regclass('public.kg_items') IS NULL
    OR to_regclass('public.league_duels') IS NULL OR to_regprocedure('public.get_public_leaderboard()') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: zuerst Etappe 4 (20261028210000) anwenden';
 END IF;
END $$;

-- Erweiterte Kategorien, Freischaltart 'pass', Buchungsgrund 'pass'
ALTER TABLE public.kg_items DROP CONSTRAINT IF EXISTS kg_items_category_check;
ALTER TABLE public.kg_items ADD CONSTRAINT kg_items_category_check CHECK (category IN ('avatar','aura','banner','rahmen','titel','handschuhe','emote','einlauf'));
ALTER TABLE public.kg_items DROP CONSTRAINT IF EXISTS kg_items_unlock_check;
ALTER TABLE public.kg_items ADD CONSTRAINT kg_items_unlock_check CHECK (unlock IN ('start','rank','shop','pass'));
ALTER TABLE public.kg_ledger DROP CONSTRAINT IF EXISTS kg_ledger_reason_check;
ALTER TABLE public.kg_ledger ADD CONSTRAINT kg_ledger_reason_check CHECK (reason IN ('start','training','training_fix','quest','purchase','admin','pass'));
ALTER TABLE public.kg_equipped ADD COLUMN IF NOT EXISTS emote text REFERENCES public.kg_items(key);
ALTER TABLE public.kg_equipped ADD COLUMN IF NOT EXISTS einlauf text REFERENCES public.kg_items(key);

INSERT INTO public.kg_items(key,category,name,description,rarity,min_rank,unlock,price,design,sort_order) VALUES
-- Emotes (positive, vorgegebene Texte)
 ('m_respekt','emote','Respekt.','Für einen fairen Kampf.','common','F','start',NULL,'{"txt":"RESPEKT.","shape":"cloud","col":"#4fe0a6"}',700),
 ('m_gg','emote','GG!','Gutes Duell!','common','F','start',NULL,'{"txt":"GG!","shape":"burst","col":"#4fa3ff"}',701),
 ('m_deckung','emote','Deckung hoch!',NULL,'common','F','start',NULL,'{"txt":"DECKUNG HOCH!","shape":"burst","col":"#f6f0e4"}',702),
 ('m_runde','emote','Noch eine Runde!',NULL,'common','F','start',NULL,'{"txt":"NOCH EINE RUNDE!","shape":"cloud","col":"#ffcc33"}',703),
 ('m_danke','emote','Danke, Coach!',NULL,'common','F','shop',150,'{"txt":"DANKE, COACH!","shape":"cloud","col":"#ffd1e2"}',710),
 ('m_stark','emote','Stark!',NULL,'common','F','shop',150,'{"txt":"STARK!","shape":"burst","col":"#ff8a3c"}',711),
 ('m_faust','emote','Faust drauf!',NULL,'common','F','shop',200,'{"txt":"FAUST DRAUF!","shape":"jag","col":"#f2c14e"}',712),
 ('m_brenn','emote','Ich brenne!',NULL,'rare','E','shop',350,'{"txt":"ICH BRENNE!","shape":"jag","col":"#ff8a3c"}',720),
 ('m_auge','emote','…!?',NULL,'rare','E','shop',350,'{"txt":"…!?","shape":"jag","col":"#f6f0e4"}',721),
 ('m_revanche','emote','Revanche?',NULL,'rare','E','shop',450,'{"txt":"REVANCHE?","shape":"cloud","col":"#b874ff"}',722),
 ('m_bereit','emote','Bereit!',NULL,'epic','D','shop',700,'{"txt":"BEREIT!","shape":"jag","col":"#4fc3ff"}',730),
 ('m_kg','emote','Kampfgeist!!',NULL,'epic','D','shop',800,'{"txt":"KAMPF-GEIST!!","shape":"burst","col":"#ff5a1f"}',731),
 ('m_unbeug','emote','Unbeugsam!',NULL,'epic','C','shop',1200,'{"txt":"UNBEUG-SAM!","shape":"burst","col":"#ffcc33"}',740),
 ('m_stille','emote','Stille …',NULL,'epic','C','shop',1200,'{"txt":"…","shape":"jag","col":"#4fc3ff"}',741),
 ('m_stufe','emote','Nächste Stufe.',NULL,'leg','B','shop',1800,'{"txt":"NÄCHSTE STUFE.","shape":"cloud","col":"#ff8a8a"}',750),
 ('m_legende','emote','Wie eine Legende!',NULL,'leg','A','shop',2800,'{"txt":"WIE EINE LEGENDE!","shape":"burst","col":"#f2c14e"}',760),
 ('m_srang','emote','S-Rang.',NULL,'myth','S','shop',4000,'{"txt":"S-RANG.","shape":"burst","col":"#f2c14e"}',770),
 ('m_pass_feuer','emote','Monatsfeuer!','Kampfpfad-Belohnung (Stufe 10).','epic','F','pass',NULL,'{"txt":"MONATS-FEUER!","shape":"jag","col":"#ff5a1f"}',780),
-- Einlauf
 ('e_slam','einlauf','Speedline-Slam',NULL,'common','F','start',NULL,'{"ic":"#f6f0e4","word":"KAMPF!"}',800),
 ('e_ring','einlauf','Ringglocke','Ding ding, die erste Runde beginnt.','common','F','shop',250,'{"ic":"#ffcc33","word":"DING DING!"}',810),
 ('e_donner','einlauf','Donnerschlag',NULL,'rare','E','shop',500,'{"ic":"#7fd0ff","word":"DONNER!","flash":true}',820),
 ('e_glut','einlauf','Glutsturm',NULL,'epic','D','shop',900,'{"ic":"#ff5a1f","word":"GLUT!","sparks":true}',830),
 ('e_kirsch','einlauf','Kirschblütenregen',NULL,'epic','D','shop',1000,'{"ic":"#ff9cc0","word":"BLÜTE","petals":true}',831),
 ('e_frost','einlauf','Frostauftritt',NULL,'epic','C','shop',1400,'{"ic":"#c9f6ff","word":"EISKALT","flash":true}',840),
 ('e_limit','einlauf','Limit Break',NULL,'leg','B','shop',2200,'{"ic":"#ffcc33","word":"LIMIT BREAK","flash":true,"sparks":true}',850),
 ('e_schatten','einlauf','Aus dem Schatten',NULL,'leg','A','shop',3000,'{"ic":"#b874ff","word":"AUS DEM SCHATTEN","dark":true}',860),
 ('e_rangs','einlauf','Rang-S-Auftritt',NULL,'myth','S','shop',4500,'{"ic":"#f2c14e","word":"RANG S","flash":true,"sparks":true,"dark":true}',870),
 ('e_pass_sturm','einlauf','Monatssturm','Kampfpfad-Belohnung (Stufe 20).','leg','F','pass',NULL,'{"ic":"#4fa3ff","word":"MONATSSTURM","flash":true,"sparks":true}',880),
-- Weitere Kampfpfad-Belohnungen
 ('b_pass','banner','Kampfpfad-Banner','Kampfpfad-Belohnung (Stufe 15).','epic','F','pass',NULL,'{"bn":"pass"}',390),
 ('f_pass','rahmen','Kampfpfad-Rahmen','Kampfpfad-Belohnung (Stufe 25).','leg','F','pass',NULL,'{"fr":"pass"}',490),
 ('t_pass','titel','Pfadbezwinger','Kampfpfad-Belohnung (Stufe 30).','myth','F','pass',NULL,'{}',590)
ON CONFLICT(key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Kampfpfad
CREATE TABLE IF NOT EXISTS public.kg_pass_settings(
 id smallint PRIMARY KEY DEFAULT 1 CHECK (id=1),
 kp_training integer NOT NULL DEFAULT 10 CHECK (kp_training BETWEEN 0 AND 100),
 kp_quest_weekly integer NOT NULL DEFAULT 10 CHECK (kp_quest_weekly BETWEEN 0 AND 100),
 kp_quest_daily integer NOT NULL DEFAULT 5 CHECK (kp_quest_daily BETWEEN 0 AND 100),
 kp_quest_chest integer NOT NULL DEFAULT 20 CHECK (kp_quest_chest BETWEEN 0 AND 100),
 kp_duel_played integer NOT NULL DEFAULT 10 CHECK (kp_duel_played BETWEEN 0 AND 100),
 kp_duel_won integer NOT NULL DEFAULT 15 CHECK (kp_duel_won BETWEEN 0 AND 100),
 kp_per_tier integer NOT NULL DEFAULT 20 CHECK (kp_per_tier BETWEEN 5 AND 500),
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES public.profiles(id)
);
INSERT INTO public.kg_pass_settings(id) VALUES (1) ON CONFLICT(id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.kg_pass_tiers(
 tier smallint PRIMARY KEY CHECK (tier BETWEEN 1 AND 30),
 coins integer NOT NULL CHECK (coins BETWEEN 0 AND 1000),
 item_key text REFERENCES public.kg_items(key),
 substitute_coins integer NOT NULL DEFAULT 0 CHECK (substitute_coins BETWEEN 0 AND 1000)
);
INSERT INTO public.kg_pass_tiers(tier,coins,item_key,substitute_coins)
SELECT t, CASE t WHEN 5 THEN 100 WHEN 30 THEN 150 WHEN 10 THEN 0 WHEN 15 THEN 0 WHEN 20 THEN 0 WHEN 25 THEN 0 ELSE 15 END,
       CASE t WHEN 10 THEN 'm_pass_feuer' WHEN 15 THEN 'b_pass' WHEN 20 THEN 'e_pass_sturm' WHEN 25 THEN 'f_pass' WHEN 30 THEN 't_pass' END,
       CASE WHEN t IN (10,15,20,25,30) THEN 150 ELSE 0 END
FROM generate_series(1,30) t
ON CONFLICT(tier) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.kg_pass_claims(
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 month date NOT NULL CHECK (extract(day FROM month)=1),
 tier smallint NOT NULL CHECK (tier BETWEEN 1 AND 30),
 coins integer NOT NULL CHECK (coins>=0),
 item_key text REFERENCES public.kg_items(key),
 ledger_id bigint UNIQUE REFERENCES public.kg_ledger(id),
 points integer NOT NULL,
 claimed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(profile_id, month, tier)
);

-- ---------------------------------------------------------------------------
-- Emotes
CREATE TABLE IF NOT EXISTS public.kg_emote_events(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 sender_id uuid NOT NULL REFERENCES public.profiles(id),
 context text NOT NULL CHECK (context IN ('duel','podium')),
 duel_id uuid REFERENCES public.league_duels(id),
 target_id uuid REFERENCES public.profiles(id),
 month date,
 day date NOT NULL DEFAULT (now() AT TIME ZONE 'Europe/Zurich')::date,
 emote_key text NOT NULL REFERENCES public.kg_items(key),
 created_at timestamptz NOT NULL DEFAULT now(),
 hidden_at timestamptz,
 hidden_by uuid REFERENCES public.profiles(id),
 CHECK ((context='duel' AND duel_id IS NOT NULL AND target_id IS NULL) OR (context='podium' AND target_id IS NOT NULL AND duel_id IS NULL AND month IS NOT NULL)),
 CHECK (target_id IS NULL OR target_id<>sender_id)
);
CREATE INDEX IF NOT EXISTS kg_emote_events_duel_idx ON public.kg_emote_events(duel_id, id DESC) WHERE duel_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS kg_emote_events_podium_idx ON public.kg_emote_events(month, target_id) WHERE context='podium';
CREATE UNIQUE INDEX IF NOT EXISTS kg_emote_events_podium_daily ON public.kg_emote_events(sender_id, target_id, day) WHERE context='podium';

CREATE TABLE IF NOT EXISTS public.kg_emote_mutes(
 profile_id uuid PRIMARY KEY REFERENCES public.profiles(id),
 muted_by uuid REFERENCES public.profiles(id),
 muted_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kg_pass_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_pass_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_pass_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_emote_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_emote_mutes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kg_pass_settings, public.kg_pass_tiers, public.kg_pass_claims, public.kg_emote_events, public.kg_emote_mutes FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Bestehende Funktionen um die Plätze Emote (Sieger-Emote) und Einlauf erweitern
CREATE OR REPLACE FUNCTION league_private.kg_look(p uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE e public.kg_equipped; lvl integer := league_private.kg_level(league_private.kg_exp(p)); r jsonb := '{}'::jsonb; slot text; k text; it public.kg_items;
 defaults jsonb := '{"avatar":"a_kenji","aura":"u_none","banner":"b_dojo","rahmen":"f_none","titel":"t_rookie","handschuhe":"g_rot","emote":"m_respekt","einlauf":"e_slam"}';
BEGIN
 SELECT * INTO e FROM public.kg_equipped x WHERE x.profile_id=p;
 FOREACH slot IN ARRAY ARRAY['avatar','aura','banner','rahmen','titel','handschuhe','emote','einlauf'] LOOP
  k := CASE slot WHEN 'avatar' THEN e.avatar WHEN 'aura' THEN e.aura WHEN 'banner' THEN e.banner WHEN 'rahmen' THEN e.rahmen
                 WHEN 'titel' THEN e.titel WHEN 'handschuhe' THEN e.handschuhe WHEN 'emote' THEN e.emote ELSE e.einlauf END;
  it := NULL;
  IF k IS NOT NULL THEN SELECT * INTO it FROM public.kg_items x WHERE x.key=k; END IF;
  IF it.key IS NULL OR NOT league_private.kg_owns(p,it,league_private.kg_rank_idx(lvl)) THEN
   SELECT * INTO it FROM public.kg_items x WHERE x.key=defaults->>slot;
  END IF;
  r := r || pg_catalog.jsonb_build_object(slot, league_private.kg_item_json(it));
 END LOOP;
 RETURN r || pg_catalog.jsonb_build_object('level',lvl,'rank',(ARRAY['F','E','D','C','B','A','S'])[league_private.kg_rank_idx(lvl)+1]);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.equip_kg_item(p_slot text, p_item_key text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); it public.kg_items; ri integer;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RAISE EXCEPTION 'Der Shop ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_slot IS NULL OR p_slot NOT IN ('avatar','aura','banner','rahmen','titel','handschuhe','emote','einlauf') THEN RAISE EXCEPTION 'Unbekannter Platz' USING ERRCODE='22023'; END IF;
 IF p_item_key IS NOT NULL THEN
  SELECT * INTO it FROM public.kg_items x WHERE x.key=p_item_key;
  IF NOT FOUND OR it.category<>p_slot THEN RAISE EXCEPTION 'Dieses Item passt nicht an diesen Platz' USING ERRCODE='22023'; END IF;
  ri := league_private.kg_rank_idx(league_private.kg_level(league_private.kg_exp(me.id)));
  IF NOT league_private.kg_owns(me.id,it,ri) THEN RAISE EXCEPTION 'Dieses Item gehört dir noch nicht' USING ERRCODE='42501'; END IF;
 END IF;
 INSERT INTO public.kg_equipped(profile_id) VALUES (me.id) ON CONFLICT (profile_id) DO NOTHING;
 UPDATE public.kg_equipped x SET
  avatar=CASE WHEN p_slot='avatar' THEN p_item_key ELSE x.avatar END, aura=CASE WHEN p_slot='aura' THEN p_item_key ELSE x.aura END,
  banner=CASE WHEN p_slot='banner' THEN p_item_key ELSE x.banner END, rahmen=CASE WHEN p_slot='rahmen' THEN p_item_key ELSE x.rahmen END,
  titel=CASE WHEN p_slot='titel' THEN p_item_key ELSE x.titel END, handschuhe=CASE WHEN p_slot='handschuhe' THEN p_item_key ELSE x.handschuhe END,
  emote=CASE WHEN p_slot='emote' THEN p_item_key ELSE x.emote END, einlauf=CASE WHEN p_slot='einlauf' THEN p_item_key ELSE x.einlauf END,
  updated_at=now()
 WHERE x.profile_id=me.id;
 RETURN pg_catalog.jsonb_build_object('look',league_private.kg_look(me.id));
END;
$fn$;

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen (nicht aufrufbar für Clients)
CREATE OR REPLACE FUNCTION league_private.kg_month(p date)
RETURNS date LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$ SELECT pg_catalog.date_trunc('month', p)::date $fn$;

CREATE OR REPLACE FUNCTION league_private.kg_pass_points(p uuid, p_month date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE s public.kg_pass_settings; m0 date := league_private.kg_month(p_month); m1 date; tr integer; qw integer; qd integer; qc integer; dp integer; dw integer;
 pt integer; pq integer; pd integer; total integer;
BEGIN
 m1 := (m0 + interval '1 month')::date;
 SELECT * INTO s FROM public.kg_pass_settings WHERE id=1;
 SELECT count(*) INTO tr FROM public.training_submissions t
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
 pt := tr*s.kp_training; pq := qw*s.kp_quest_weekly + qd*s.kp_quest_daily + qc*s.kp_quest_chest; pd := dp*s.kp_duel_played + dw*s.kp_duel_won;
 total := pt+pq+pd;
 RETURN pg_catalog.jsonb_build_object('month',m0,'trainings',tr,'quests_weekly',qw,'quests_daily',qd,'quests_chest',qc,'duels_played',dp,'duels_won',dw,
  'points_trainings',pt,'points_quests',pq,'points_duels',pd,'total',total,'per_tier',s.kp_per_tier,'tier',LEAST(30,total/s.kp_per_tier));
END;
$fn$;

-- Belohnung einer Stufe für ein Profil (Item schon vorhanden → Ersatz-Coins)
CREATE OR REPLACE FUNCTION league_private.kg_pass_reward(p uuid, t public.kg_pass_tiers)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE it public.kg_items; owned boolean := false;
BEGIN
 IF t.item_key IS NOT NULL THEN
  SELECT * INTO it FROM public.kg_items x WHERE x.key=t.item_key;
  owned := EXISTS (SELECT 1 FROM public.kg_inventory i WHERE i.profile_id=p AND i.item_key=t.item_key);
 END IF;
 RETURN pg_catalog.jsonb_build_object('coins',t.coins + CASE WHEN owned THEN t.substitute_coins ELSE 0 END,
  'item',CASE WHEN it.key IS NOT NULL AND NOT owned THEN league_private.kg_item_json(it) END,
  'substitute',owned,'substitute_for',CASE WHEN owned THEN it.name END);
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.kg_is_staff(me public.profiles)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$ SELECT me.id IS NOT NULL AND me.role IN ('admin','coach') $fn$;

CREATE OR REPLACE FUNCTION league_private.kg_emote_json(ev public.kg_emote_events, p_staff boolean)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object('id',ev.id,'sender_id',ev.sender_id,
  'sender',(SELECT p.display_name FROM public.profiles p WHERE p.id=ev.sender_id),
  'emote',(SELECT league_private.kg_item_json(i) FROM public.kg_items i WHERE i.key=ev.emote_key),
  'created_at',ev.created_at,'hidden',ev.hidden_at IS NOT NULL)
$fn$;

CREATE OR REPLACE FUNCTION league_private.kg_my_emotes(p uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT coalesce(pg_catalog.jsonb_agg(league_private.kg_item_json(i) ORDER BY i.sort_order),'[]'::jsonb)
 FROM public.kg_items i
 WHERE i.category='emote' AND league_private.kg_owns(p,i,league_private.kg_rank_idx(league_private.kg_level(league_private.kg_exp(p))))
$fn$;

CREATE OR REPLACE FUNCTION league_private.kg_duel_open(d public.league_duels)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $fn$
 SELECT d.status IN ('active','awaiting_reviews') OR (d.status='settled' AND d.settled_at > now() - interval '7 days')
$fn$;

REVOKE ALL ON FUNCTION league_private.kg_month(date), league_private.kg_pass_points(uuid,date), league_private.kg_pass_reward(uuid,public.kg_pass_tiers),
 league_private.kg_is_staff(public.profiles), league_private.kg_emote_json(public.kg_emote_events,boolean), league_private.kg_my_emotes(uuid),
 league_private.kg_duel_open(public.league_duels) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPCs: Kampfpfad
CREATE OR REPLACE FUNCTION public.get_my_kampfpfad(p_month date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); on_ boolean := league_private.flag_on('kampfgeist_shop');
 today date := league_private.zurich_today(); cur date; m date; pts jsonb; reached_tier integer; prev_open integer;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT on_ AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 cur := league_private.kg_month(today);
 m := league_private.kg_month(coalesce(p_month,today));
 IF m NOT IN (cur, (cur - interval '1 month')::date) THEN RAISE EXCEPTION 'Nur der laufende und der letzte Monat' USING ERRCODE='22023'; END IF;
 pts := league_private.kg_pass_points(me.id, m);
 reached_tier := (pts->>'tier')::integer;
 IF m=cur THEN
  SELECT count(*) INTO prev_open FROM public.kg_pass_tiers t
  WHERE t.tier<=(league_private.kg_pass_points(me.id,(cur - interval '1 month')::date)->>'tier')::integer
    AND NOT EXISTS (SELECT 1 FROM public.kg_pass_claims c WHERE c.profile_id=me.id AND c.month=(cur - interval '1 month')::date AND c.tier=t.tier);
 END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT on_,'can_claim',on_,'today',today,'month',m,'current_month',cur,
  'days_left',CASE WHEN m=cur THEN ((cur + interval '1 month')::date - today) ELSE 0 END,
  'points',pts,'previous_open',coalesce(prev_open,0),
  'tiers',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('tier',t.tier,'need',t.tier*(pts->>'per_tier')::integer,
     'reached',t.tier<=reached_tier,'claimed',c.tier IS NOT NULL,
     'reward',CASE WHEN c.tier IS NOT NULL THEN pg_catalog.jsonb_build_object('coins',c.coins,
        'item',(SELECT league_private.kg_item_json(i) FROM public.kg_items i WHERE i.key=c.item_key),'substitute',false)
       ELSE league_private.kg_pass_reward(me.id,t) END) ORDER BY t.tier)
   FROM public.kg_pass_tiers t LEFT JOIN public.kg_pass_claims c ON c.profile_id=me.id AND c.month=m AND c.tier=t.tier));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.claim_kampfpfad(p_month date, p_tier integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); cur date; m date; pts jsonb; reached integer; t public.kg_pass_tiers; rw jsonb;
 lid bigint; n integer := 0; coins integer := 0; items jsonb := '[]'::jsonb; ik text;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RAISE EXCEPTION 'Der Kampfpfad ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_month IS NULL THEN RAISE EXCEPTION 'Bitte einen Monat angeben' USING ERRCODE='22023'; END IF;
 cur := league_private.kg_month(league_private.zurich_today()); m := league_private.kg_month(p_month);
 IF m NOT IN (cur, (cur - interval '1 month')::date) THEN RAISE EXCEPTION 'Dieser Kampfpfad ist abgelaufen' USING ERRCODE='22023'; END IF;
 PERFORM league_private.kg_sync(me.id);  -- Coin-Buch nachtragen und Konto sperren
 pts := league_private.kg_pass_points(me.id, m); reached := (pts->>'tier')::integer;
 IF p_tier IS NOT NULL AND (p_tier<1 OR p_tier>30) THEN RAISE EXCEPTION 'Unbekannte Stufe' USING ERRCODE='22023'; END IF;
 IF p_tier IS NOT NULL AND p_tier>reached THEN RAISE EXCEPTION 'Diese Stufe hast du noch nicht erreicht' USING ERRCODE='22023'; END IF;
 IF p_tier IS NOT NULL AND EXISTS (SELECT 1 FROM public.kg_pass_claims c WHERE c.profile_id=me.id AND c.month=m AND c.tier=p_tier) THEN
  RAISE EXCEPTION 'Diese Stufe hast du schon abgeholt' USING ERRCODE='23505';
 END IF;
 FOR t IN SELECT * FROM public.kg_pass_tiers x WHERE x.tier<=reached AND (p_tier IS NULL OR x.tier=p_tier)
          AND NOT EXISTS (SELECT 1 FROM public.kg_pass_claims c WHERE c.profile_id=me.id AND c.month=m AND c.tier=x.tier) ORDER BY x.tier LOOP
  rw := league_private.kg_pass_reward(me.id, t); lid := NULL; ik := rw->'item'->>'key';
  IF (rw->>'coins')::integer>0 THEN
   INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note,created_by)
   VALUES (me.id,(rw->>'coins')::integer,'pass',pg_catalog.to_char(m,'YYYY-MM')||':'||t.tier::text,
           'Kampfpfad '||pg_catalog.to_char(m,'MM.YYYY')||' · Stufe '||t.tier::text,me.id) RETURNING id INTO lid;
  END IF;
  IF ik IS NOT NULL THEN
   INSERT INTO public.kg_inventory(profile_id,item_key,price_paid) VALUES (me.id,ik,0) ON CONFLICT DO NOTHING;
   items := items || pg_catalog.jsonb_build_array(rw->'item');
  END IF;
  INSERT INTO public.kg_pass_claims(profile_id,month,tier,coins,item_key,ledger_id,points)
  VALUES (me.id,m,t.tier,(rw->>'coins')::integer,ik,lid,(pts->>'total')::integer);
  n := n+1; coins := coins+(rw->>'coins')::integer;
 END LOOP;
 IF n=0 THEN RAISE EXCEPTION 'Gerade gibt es nichts abzuholen' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('month',m,'claimed',n,'coins',coins,'items',items,'balance',league_private.kg_balance(me.id));
END;
$fn$;

-- ---------------------------------------------------------------------------
-- RPCs: Emotes im Duell
CREATE OR REPLACE FUNCTION public.get_duel_kampfgeist(p_duel_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); on_ boolean := league_private.flag_on('kampfgeist_shop'); staff boolean; muted boolean;
BEGIN
 IF me.id IS NULL THEN RETURN NULL; END IF;
 IF NOT on_ AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 IF p_duel_ids IS NULL OR coalesce(pg_catalog.array_length(p_duel_ids,1),0)>60 THEN RAISE EXCEPTION 'Zu viele Duelle auf einmal' USING ERRCODE='22023'; END IF;
 staff := league_private.kg_is_staff(me);
 muted := EXISTS (SELECT 1 FROM public.kg_emote_mutes x WHERE x.profile_id=me.id);
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT on_,'can_moderate',staff,'muted',muted,
  'my_emotes',league_private.kg_my_emotes(me.id),
  'duels',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',d.id,'status',d.status,
     'challenger',league_private.kg_look(d.challenger_id) || pg_catalog.jsonb_build_object('id',d.challenger_id,'name',(SELECT p.display_name FROM public.profiles p WHERE p.id=d.challenger_id)),
     'opponent',league_private.kg_look(d.opponent_id) || pg_catalog.jsonb_build_object('id',d.opponent_id,'name',(SELECT p.display_name FROM public.profiles p WHERE p.id=d.opponent_id)),
     'can_send',on_ AND NOT muted AND me.id IN (d.challenger_id,d.opponent_id) AND league_private.kg_duel_open(d),
     'events',coalesce((SELECT pg_catalog.jsonb_agg(league_private.kg_emote_json(e,staff) ORDER BY e.id) FROM (
        SELECT * FROM public.kg_emote_events x WHERE x.duel_id=d.id AND (x.hidden_at IS NULL OR staff) ORDER BY x.id DESC LIMIT 12) e),'[]'::jsonb)))
   FROM public.league_duels d
   WHERE d.id = ANY(p_duel_ids) AND (staff OR me.id IN (d.challenger_id,d.opponent_id))),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.send_duel_emote(p_duel_id uuid, p_emote_key text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); d public.league_duels; it public.kg_items; last_at timestamptz; n integer; ev public.kg_emote_events;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RAISE EXCEPTION 'Emotes sind noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF EXISTS (SELECT 1 FROM public.kg_emote_mutes x WHERE x.profile_id=me.id) THEN RAISE EXCEPTION 'Deine Emotes sind gerade pausiert' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.league_duels x WHERE x.id=p_duel_id;
 IF NOT FOUND OR me.id NOT IN (d.challenger_id,d.opponent_id) THEN RAISE EXCEPTION 'Emotes gibt es nur in deinen eigenen Duellen' USING ERRCODE='42501'; END IF;
 IF NOT league_private.kg_duel_open(d) THEN RAISE EXCEPTION 'In diesem Duell kannst du keine Emotes mehr senden' USING ERRCODE='22023'; END IF;
 SELECT * INTO it FROM public.kg_items x WHERE x.key=p_emote_key AND x.category='emote';
 IF NOT FOUND OR NOT league_private.kg_owns(me.id,it,league_private.kg_rank_idx(league_private.kg_level(league_private.kg_exp(me.id)))) THEN
  RAISE EXCEPTION 'Dieses Emote gehört dir noch nicht' USING ERRCODE='42501';
 END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('kg_emote:'||me.id::text));
 SELECT max(x.created_at), count(*) INTO last_at, n FROM public.kg_emote_events x WHERE x.duel_id=d.id AND x.sender_id=me.id;
 IF n>=30 THEN RAISE EXCEPTION 'In diesem Duell hast du schon genug Emotes gesendet' USING ERRCODE='22023'; END IF;
 IF last_at IS NOT NULL AND last_at > now() - interval '15 seconds' THEN RAISE EXCEPTION 'Kurz warten, dann kannst du wieder ein Emote senden' USING ERRCODE='22023'; END IF;
 INSERT INTO public.kg_emote_events(sender_id,context,duel_id,emote_key) VALUES (me.id,'duel',d.id,it.key) RETURNING * INTO ev;
 RETURN league_private.kg_emote_json(ev,false);
END;
$fn$;

-- ---------------------------------------------------------------------------
-- RPCs: Podium (Top 3 des Monats, wie get_public_leaderboard)
CREATE OR REPLACE FUNCTION public.get_podium_kampfgeist()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); on_ boolean := league_private.flag_on('kampfgeist_shop'); staff boolean; muted boolean;
 m date := league_private.kg_month(league_private.zurich_today()); today date := league_private.zurich_today();
BEGIN
 IF me.id IS NULL THEN RETURN NULL; END IF;
 IF NOT on_ AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 staff := league_private.kg_is_staff(me);
 muted := EXISTS (SELECT 1 FROM public.kg_emote_mutes x WHERE x.profile_id=me.id);
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT on_,'can_moderate',staff,'muted',muted,'month',m,
  'my_emotes',league_private.kg_my_emotes(me.id),
  'places',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('rank',lb.rank_position,'name',p.display_name,'is_me',p.id=me.id,
     'look',league_private.kg_look(p.id),
     'reactions',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('emote',league_private.kg_item_json(i),'count',r.n) ORDER BY r.n DESC, i.sort_order)
        FROM (SELECT e.emote_key, count(*) n FROM public.kg_emote_events e WHERE e.context='podium' AND e.month=m AND e.target_id=p.id AND e.hidden_at IS NULL GROUP BY e.emote_key) r
        JOIN public.kg_items i ON i.key=r.emote_key),'[]'::jsonb),
     'reacted_today',EXISTS (SELECT 1 FROM public.kg_emote_events e WHERE e.context='podium' AND e.sender_id=me.id AND e.target_id=p.id AND e.day=today),
     'can_react',on_ AND NOT muted AND p.id<>me.id AND NOT EXISTS (SELECT 1 FROM public.kg_emote_events e WHERE e.context='podium' AND e.sender_id=me.id AND e.target_id=p.id AND e.day=today))
     ORDER BY lb.rank_position)
   FROM (SELECT x.rank_position, x.boxer_name FROM public.get_public_leaderboard() x WHERE x.rank_position<=3 AND x.monthly_points>0) lb
   JOIN public.profiles p ON pg_catalog.lower(p.display_name)=pg_catalog.lower(lb.boxer_name) AND p.is_active AND p.archived_at IS NULL),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.react_podium(p_display_name text, p_emote_key text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles; it public.kg_items; m date := league_private.kg_month(league_private.zurich_today());
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RAISE EXCEPTION 'Emotes sind noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF EXISTS (SELECT 1 FROM public.kg_emote_mutes x WHERE x.profile_id=me.id) THEN RAISE EXCEPTION 'Deine Emotes sind gerade pausiert' USING ERRCODE='42501'; END IF;
 SELECT p.* INTO t FROM public.get_public_leaderboard() x JOIN public.profiles p ON pg_catalog.lower(p.display_name)=pg_catalog.lower(x.boxer_name)
  WHERE x.rank_position<=3 AND x.monthly_points>0 AND p.is_active AND p.archived_at IS NULL
    AND pg_catalog.lower(x.boxer_name)=pg_catalog.lower(pg_catalog.btrim(coalesce(p_display_name,''))) LIMIT 1;
 IF t.id IS NULL THEN RAISE EXCEPTION 'Reagieren geht nur auf das aktuelle Podium' USING ERRCODE='22023'; END IF;
 IF t.id=me.id THEN RAISE EXCEPTION 'Auf dich selbst kannst du nicht reagieren' USING ERRCODE='22023'; END IF;
 SELECT * INTO it FROM public.kg_items x WHERE x.key=p_emote_key AND x.category='emote';
 IF NOT FOUND OR NOT league_private.kg_owns(me.id,it,league_private.kg_rank_idx(league_private.kg_level(league_private.kg_exp(me.id)))) THEN
  RAISE EXCEPTION 'Dieses Emote gehört dir noch nicht' USING ERRCODE='42501';
 END IF;
 INSERT INTO public.kg_emote_events(sender_id,context,target_id,month,emote_key) VALUES (me.id,'podium',t.id,m,it.key);
 RETURN pg_catalog.jsonb_build_object('name',t.display_name,'emote',league_private.kg_item_json(it));
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'Heute hast du schon reagiert – morgen wieder' USING ERRCODE='23505';
END;
$fn$;

-- ---------------------------------------------------------------------------
-- RPCs: Moderation und Admin
CREATE OR REPLACE FUNCTION public.hide_kg_emote(p_event_id bigint)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); ev public.kg_emote_events;
BEGIN
 IF NOT league_private.kg_is_staff(me) THEN RAISE EXCEPTION 'Nur Coaches und Admin blenden Emotes aus' USING ERRCODE='42501'; END IF;
 UPDATE public.kg_emote_events x SET hidden_at=coalesce(x.hidden_at,now()), hidden_by=coalesce(x.hidden_by,me.id) WHERE x.id=p_event_id RETURNING * INTO ev;
 IF ev.id IS NULL THEN RAISE EXCEPTION 'Emote nicht gefunden' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('id',ev.id,'hidden',true);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_set_emote_mute(p_profile_id uuid, p_muted boolean)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin pausiert Emotes' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_profile_id;
 IF NOT FOUND OR p_muted IS NULL THEN RAISE EXCEPTION 'Bitte ein Profil wählen' USING ERRCODE='22023'; END IF;
 IF p_muted THEN INSERT INTO public.kg_emote_mutes(profile_id,muted_by) VALUES (t.id,me.id) ON CONFLICT (profile_id) DO NOTHING;
 ELSE DELETE FROM public.kg_emote_mutes x WHERE x.profile_id=t.id; END IF;
 RETURN pg_catalog.jsonb_build_object('profile',t.display_name,'muted',p_muted);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_kg_social()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); s public.kg_pass_settings;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.kg_pass_settings WHERE id=1;
 RETURN pg_catalog.jsonb_build_object(
  'pass',pg_catalog.jsonb_build_object('kp_training',s.kp_training,'kp_quest_weekly',s.kp_quest_weekly,'kp_quest_daily',s.kp_quest_daily,
    'kp_quest_chest',s.kp_quest_chest,'kp_duel_played',s.kp_duel_played,'kp_duel_won',s.kp_duel_won,'kp_per_tier',s.kp_per_tier),
  'events',coalesce((SELECT pg_catalog.jsonb_agg(league_private.kg_emote_json(e,true) || pg_catalog.jsonb_build_object('context',e.context,
     'target',(SELECT p.display_name FROM public.profiles p WHERE p.id=e.target_id),
     'duel',(SELECT (SELECT a.display_name FROM public.profiles a WHERE a.id=d.challenger_id)||' vs. '||(SELECT b.display_name FROM public.profiles b WHERE b.id=d.opponent_id)
             FROM public.league_duels d WHERE d.id=e.duel_id)) ORDER BY e.id DESC)
    FROM (SELECT * FROM public.kg_emote_events x ORDER BY x.id DESC LIMIT 60) e),'[]'::jsonb),
  'profiles',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,'role',p.role,
     'muted',EXISTS (SELECT 1 FROM public.kg_emote_mutes x WHERE x.profile_id=p.id)) ORDER BY pg_catalog.lower(p.display_name))
    FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_update_kg_pass(p_kp_training integer, p_kp_quest_weekly integer, p_kp_quest_daily integer,
 p_kp_quest_chest integer, p_kp_duel_played integer, p_kp_duel_won integer, p_kp_per_tier integer)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); s public.kg_pass_settings;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin ändert den Kampfpfad' USING ERRCODE='42501'; END IF;
 IF p_kp_training IS NULL OR p_kp_quest_weekly IS NULL OR p_kp_quest_daily IS NULL OR p_kp_quest_chest IS NULL OR p_kp_duel_played IS NULL OR p_kp_duel_won IS NULL
    OR LEAST(p_kp_training,p_kp_quest_weekly,p_kp_quest_daily,p_kp_quest_chest,p_kp_duel_played,p_kp_duel_won)<0
    OR GREATEST(p_kp_training,p_kp_quest_weekly,p_kp_quest_daily,p_kp_quest_chest,p_kp_duel_played,p_kp_duel_won)>100 THEN
  RAISE EXCEPTION 'Punkte pro Aktivität zwischen 0 und 100' USING ERRCODE='22023';
 END IF;
 IF p_kp_per_tier IS NULL OR p_kp_per_tier NOT BETWEEN 5 AND 500 THEN RAISE EXCEPTION 'Punkte pro Stufe zwischen 5 und 500' USING ERRCODE='22023'; END IF;
 UPDATE public.kg_pass_settings x SET kp_training=p_kp_training, kp_quest_weekly=p_kp_quest_weekly, kp_quest_daily=p_kp_quest_daily,
  kp_quest_chest=p_kp_quest_chest, kp_duel_played=p_kp_duel_played, kp_duel_won=p_kp_duel_won, kp_per_tier=p_kp_per_tier, updated_at=now(), updated_by=me.id
 WHERE x.id=1 RETURNING * INTO s;
 RETURN pg_catalog.jsonb_build_object('kp_training',s.kp_training,'kp_per_tier',s.kp_per_tier);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_kampfpfad(date), public.claim_kampfpfad(date,integer), public.get_duel_kampfgeist(uuid[]),
 public.send_duel_emote(uuid,text), public.get_podium_kampfgeist(), public.react_podium(text,text), public.hide_kg_emote(bigint),
 public.admin_set_emote_mute(uuid,boolean), public.admin_kg_social(),
 public.admin_update_kg_pass(integer,integer,integer,integer,integer,integer,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_kampfpfad(date), public.claim_kampfpfad(date,integer), public.get_duel_kampfgeist(uuid[]),
 public.send_duel_emote(uuid,text), public.get_podium_kampfgeist(), public.react_podium(text,text), public.hide_kg_emote(bigint),
 public.admin_set_emote_mute(uuid,boolean), public.admin_kg_social(),
 public.admin_update_kg_pass(integer,integer,integer,integer,integer,integer,integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
