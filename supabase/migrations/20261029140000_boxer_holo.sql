BEGIN;
-- Etappe 9 (28.10.2026, Owner-Auftrag): Boxer-Holo – jeder gestaltet seinen eigenen Boxer.
-- * Körper gratis: 8 Hauttöne, 18 Frisuren für alle Haartypen (glatt, wellig, lockig, Afro, Locs, Braids, Cornrows, Twists …),
--   8 Haarfarben, 8 Grundaugenfarben.
-- * Start-Garderobe gratis: Kappe, Stirnband, Sport-Hijab, Tanktop, T-Shirt, Hoodie (Kapuze auf/ab), Trainingsjacke,
--   Boxershorts, kurze Hose, Jogginghose, Trainingshose, Bandagen oder Handschuhe, Boxstiefel, Sneaker, Trainer-Mantel,
--   Holo-Plattform und 4 Posen. Farben frei. Hose und Schuhe trägt jeder Holo immer.
-- * Shop (Kampfgeist-Coins) und Belohnungen (Level, Rang, Card of the Week, erster Duellsieg): Mäntel, Handschuhe, Auren,
--   Spezial-Augen, Hintergründe, Posen; Bundles günstiger als einzeln.
-- * Profil und FUT-Karte zeigen den Holo in je einer gewählten Pose.
-- * Neues Feature-Flag boxer_holo (AUS). Admin und Trainer sehen eine Vorschau. Käufe zusätzlich nur mit Kampfgeist-Shop.
-- Bestehende Daten (Punkte, EXP, Coins, Trainings, Kampfgeist-Items) bleiben unverändert.

DO $$ BEGIN
 IF to_regprocedure('league_private.active_viewer()') IS NULL OR to_regprocedure('league_private.flag_on(text)') IS NULL
    OR to_regprocedure('league_private.kg_exp(uuid)') IS NULL OR to_regprocedure('league_private.kg_balance(uuid)') IS NULL
    OR to_regprocedure('league_private.kg_sync(uuid)') IS NULL OR to_regclass('public.kg_ledger') IS NULL OR to_regclass('public.league_duels') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Kampfgeist (20261028210000), Duelle';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('boxer_holo','Boxer-Holo (eigener Boxer, Outfits, Posen)',false) ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.holo_items(
 key text PRIMARY KEY CHECK (key ~ '^[a-z][a-z0-9_]{2,40}$'),
 slot text NOT NULL CHECK (slot IN ('hair','head','top','bottom','glove','feet','coat','aura','eyefx','scene','pose')),
 name text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 40),
 rarity text NOT NULL DEFAULT 'common' CHECK (rarity IN ('common','rare','epic','leg','myth')),
 unlock text NOT NULL CHECK (unlock IN ('start','shop','reward')),
 price integer CHECK (price IS NULL OR price BETWEEN 10 AND 20000),
 reward jsonb CHECK (reward IS NULL OR jsonb_typeof(reward)='object'),
 sort_order integer NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true,
 CHECK (key LIKE slot||'\_%'), CHECK ((unlock='shop')=(price IS NOT NULL)), CHECK ((unlock='reward')=(reward IS NOT NULL))
);
INSERT INTO public.holo_items(key,slot,name,rarity,unlock,price,reward,sort_order) VALUES
 ('hair_kurz_glatt','hair','Kurz glatt','common','start',NULL,NULL,10),('hair_stachel','hair','Stachel','common','start',NULL,NULL,11),
 ('hair_lang_glatt','hair','Lang glatt','common','start',NULL,NULL,12),('hair_undercut','hair','Undercut','common','start',NULL,NULL,13),
 ('hair_buzz','hair','Buzzcut','common','start',NULL,NULL,14),('hair_glatze','hair','Glatze','common','start',NULL,NULL,15),
 ('hair_dutts','hair','Zwei Dutts','common','start',NULL,NULL,16),('hair_zopf','hair','Pferdeschwanz','common','start',NULL,NULL,17),
 ('hair_bob','hair','Bob','common','start',NULL,NULL,18),('hair_wellig','hair','Wellig','common','start',NULL,NULL,19),
 ('hair_locken','hair','Locken','common','start',NULL,NULL,20),('hair_afro','hair','Afro','common','start',NULL,NULL,21),
 ('hair_afro_puffs','hair','Afro-Puffs','common','start',NULL,NULL,22),('hair_locs','hair','Locs','common','start',NULL,NULL,23),
 ('hair_box_braids','hair','Box Braids','common','start',NULL,NULL,24),('hair_cornrows','hair','Cornrows','common','start',NULL,NULL,25),
 ('hair_twists','hair','Twists','common','start',NULL,NULL,26),('hair_high_top','hair','High-Top Fade','common','start',NULL,NULL,27),
 ('head_cap','head','Kappe','common','start',NULL,NULL,30),('head_band','head','Stirnband','common','start',NULL,NULL,31),('head_hijab','head','Sport-Hijab','common','start',NULL,NULL,32),
 ('top_tank','top','Tanktop','common','start',NULL,NULL,40),('top_shirt','top','T-Shirt','common','start',NULL,NULL,41),
 ('top_hoodie','top','Hoodie','common','start',NULL,NULL,42),('top_jacke','top','Trainingsjacke','common','start',NULL,NULL,43),
 ('bottom_boxer','bottom','Boxershorts','common','start',NULL,NULL,50),('bottom_kurz','bottom','Kurze Hose','common','start',NULL,NULL,51),
 ('bottom_jogger','bottom','Jogginghose','common','start',NULL,NULL,52),('bottom_track','bottom','Trainingshose','common','start',NULL,NULL,53),
 ('glove_rot','glove','Rot','common','start',NULL,NULL,60),('glove_weiss','glove','Weiss','common','start',NULL,NULL,61),('glove_schwarzgold','glove','Schwarz-Gold','common','start',NULL,NULL,62),
 ('glove_eisblau','glove','Eisblau','rare','shop',450,NULL,63),('glove_glut','glove','Glut','epic','reward',NULL,'{"type":"level","min":15}',64),
 ('feet_boots','feet','Boxstiefel','common','start',NULL,NULL,70),('feet_sneaker','feet','Sneaker','common','start',NULL,NULL,71),
 ('coat_basic','coat','Trainer-Mantel','common','start',NULL,NULL,80),('coat_samurai','coat','Samurai-Jacke','epic','reward',NULL,'{"type":"level","min":25}',81),
 ('coat_neon','coat','Neon-Mantel','epic','shop',1200,NULL,82),('coat_drache','coat','Drachen-Mantel','leg','shop',1800,NULL,83),
 ('aura_flamme','aura','Flamme','epic','shop',900,NULL,90),('aura_sakura','aura','Sakura','epic','shop',900,NULL,91),
 ('aura_blitz','aura','Blitz','epic','reward',NULL,'{"type":"level","min":20}',92),('aura_schatten','aura','Schatten','leg','reward',NULL,'{"type":"level","min":30}',93),
 ('eyefx_kristall','eyefx','Kristall','epic','shop',1200,NULL,100),('eyefx_glut','eyefx','Glut-Flamme','leg','shop',1500,NULL,101),
 ('eyefx_stern','eyefx','Stern','leg','reward',NULL,'{"type":"award","kind":"cotw"}',102),('eyefx_mond','eyefx','Mond','myth','reward',NULL,'{"type":"rank","min":"A"}',103),
 ('scene_holo','scene','Holo-Plattform','common','start',NULL,NULL,110),('scene_dojo','scene','Dojo','rare','shop',700,NULL,111),
 ('scene_neon','scene','Neon-Stadt','rare','shop',700,NULL,112),('scene_arena','scene','Arena','rare','reward',NULL,'{"type":"duel_win"}',113),
 ('pose_guard','pose','Kampfstellung','common','start',NULL,NULL,120),('pose_jab','pose','Jab','common','start',NULL,NULL,121),
 ('pose_sieg','pose','Siegerpose','common','start',NULL,NULL,122),('pose_cool','pose','Cool','common','start',NULL,NULL,123),
 ('pose_flex','pose','Bizeps','rare','reward',NULL,'{"type":"level","min":10}',124),('pose_ansage','pose','Ansage','rare','shop',500,NULL,125)
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.holo_bundles(
 key text PRIMARY KEY CHECK (key ~ '^[a-z][a-z0-9_]{2,40}$'),
 name text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 40),
 description text CHECK (description IS NULL OR char_length(description)<=200),
 price integer NOT NULL CHECK (price BETWEEN 10 AND 50000),
 items text[] NOT NULL CHECK (cardinality(items) BETWEEN 2 AND 10),
 sort_order integer NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true
);
INSERT INTO public.holo_bundles(key,name,description,price,items,sort_order) VALUES
 ('drachen_bundle','Drachen-Bundle','Drachen-Mantel, Flammen-Aura, Glut-Augen und die Pose Ansage.',3400,ARRAY['coat_drache','aura_flamme','eyefx_glut','pose_ansage'],10),
 ('neon_bundle','Neon-Bundle','Neon-Mantel, Neon-Stadt und Kristall-Augen.',2400,ARRAY['coat_neon','scene_neon','eyefx_kristall'],20),
 ('sakura_bundle','Kirschblüten-Bundle','Sakura-Aura, Dojo und Eisblau-Handschuhe.',1600,ARRAY['aura_sakura','scene_dojo','glove_eisblau'],30)
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.holo_owned(
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 item_key text NOT NULL REFERENCES public.holo_items(key),
 source text NOT NULL CHECK (source IN ('shop','bundle','admin')),
 ledger_id bigint REFERENCES public.kg_ledger(id),
 note text CHECK (note IS NULL OR char_length(note)<=200),
 acquired_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (profile_id, item_key)
);
CREATE TABLE IF NOT EXISTS public.holo_config(
 profile_id uuid PRIMARY KEY REFERENCES public.profiles(id),
 config jsonb NOT NULL CHECK (jsonb_typeof(config)='object'),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.holo_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holo_bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holo_owned ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holo_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.holo_items, public.holo_bundles, public.holo_owned, public.holo_config FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen (nicht aufrufbar für Clients)
CREATE OR REPLACE FUNCTION league_private.holo_reward_ok(p uuid, r jsonb)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE lvl integer;
BEGIN
 IF p IS NULL OR r IS NULL THEN RETURN false; END IF;
 IF r->>'type' IN ('level','rank') THEN lvl := league_private.kg_level(league_private.kg_exp(p)); END IF;
 IF r->>'type'='level' THEN RETURN lvl >= coalesce((r->>'min')::integer, 1000); END IF;
 IF r->>'type'='rank' THEN RETURN league_private.kg_rank_idx(lvl) >= coalesce(pg_catalog.array_position(ARRAY['F','E','D','C','B','A','S'], r->>'min')-1, 99); END IF;
 IF r->>'type'='duel_win' THEN RETURN EXISTS (SELECT 1 FROM public.league_duels d WHERE d.winner_id=p); END IF;
 IF r->>'type'='award' THEN
  IF to_regclass('public.card_awards') IS NULL THEN RETURN false; END IF;
  RETURN EXISTS (SELECT 1 FROM public.card_awards a WHERE a.profile_id=p AND a.kind=r->>'kind' AND a.revoked_at IS NULL);
 END IF;
 RETURN false;
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.holo_reward_label(r jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT CASE r->>'type' WHEN 'level' THEN 'Ab Level '||(r->>'min') WHEN 'rank' THEN 'Ab Rang '||(r->>'min')
  WHEN 'duel_win' THEN 'Erster Duellsieg' WHEN 'award' THEN CASE r->>'kind' WHEN 'cotw' THEN 'Card of the Week' WHEN 'cotm' THEN 'Card of the Month' ELSE 'Player of the Year' END
  ELSE 'Belohnung' END
$fn$;

CREATE OR REPLACE FUNCTION league_private.holo_has(p uuid, it public.holo_items)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT it.is_active AND (it.unlock='start'
  OR EXISTS (SELECT 1 FROM public.holo_owned o WHERE o.profile_id=p AND o.item_key=it.key)
  OR (it.unlock='reward' AND league_private.holo_reward_ok(p, it.reward)))
$fn$;

-- Konfiguration prüfen und vervollständigen. p_strict: Unbekanntes oder nicht Freigeschaltetes ablehnen (Speichern);
-- sonst stillschweigend auf den Standard zurückfallen (Anzeige, z. B. wenn eine Belohnung später wegfällt).
CREATE OR REPLACE FUNCTION league_private.holo_clean(p uuid, c jsonb, p_strict boolean)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE o jsonb := '{"tone":2,"hair":"kurz_glatt","hc":"schwarz","eye":"braun","eyefx":"none","head":"none","headc":"schwarz","top":"none","hood":false,"topc":"grau","bottom":"boxer","bottomc":"rot","hands":"wraps","glove":"rot","feet":"boots","feetc":"weiss","coat":"none","aura":"none","scene":"holo","pose_profile":"guard","pose_card":"guard"}';
 k text; v text; it public.holo_items; v_slot text; opt boolean;
 cols text[] := ARRAY['schwarz','weiss','grau','rot','blau','gruen','lila','gold'];
 hcs text[] := ARRAY['schwarz','braun','dunkelbraun','blond','rot','silber','blau','pink'];
 eyes text[] := ARRAY['braun','hasel','gruen','blau','grau','gold','orange','violett'];
BEGIN
 IF c IS NULL OR pg_catalog.jsonb_typeof(c)<>'object' THEN
  IF p_strict THEN RAISE EXCEPTION 'Ungültige Einstellung' USING ERRCODE='22023'; END IF;
  RETURN o;
 END IF;
 FOR k IN SELECT pg_catalog.jsonb_object_keys(c) LOOP
  IF NOT o ? k THEN
   IF p_strict THEN RAISE EXCEPTION 'Unbekanntes Feld: %', pg_catalog.left(k,40) USING ERRCODE='22023'; END IF;
   CONTINUE;
  END IF;
  IF k='hood' THEN
   IF pg_catalog.jsonb_typeof(c->k)='boolean' THEN o := o || pg_catalog.jsonb_build_object('hood',(c->>k)::boolean);
   ELSIF p_strict THEN RAISE EXCEPTION 'Ungültiger Wert für Kapuze' USING ERRCODE='22023'; END IF;
   CONTINUE;
  END IF;
  IF k='tone' THEN
   IF pg_catalog.jsonb_typeof(c->k)='number' AND (c->>k) ~ '^[0-7]$' THEN o := o || pg_catalog.jsonb_build_object('tone',(c->>k)::integer);
   ELSIF p_strict THEN RAISE EXCEPTION 'Ungültiger Hautton' USING ERRCODE='22023'; END IF;
   CONTINUE;
  END IF;
  v := CASE WHEN pg_catalog.jsonb_typeof(c->k)='string' THEN c->>k END;
  IF v IS NULL OR pg_catalog.char_length(v)>30 THEN
   IF p_strict THEN RAISE EXCEPTION 'Ungültiger Wert für %', k USING ERRCODE='22023'; END IF;
   CONTINUE;
  END IF;
  IF k IN ('headc','topc','bottomc','feetc') OR k='hc' OR k='eye' OR k='hands' THEN
   IF (k IN ('headc','topc','bottomc','feetc') AND v=ANY(cols)) OR (k='hc' AND v=ANY(hcs)) OR (k='eye' AND v=ANY(eyes)) OR (k='hands' AND v IN ('wraps','gloves')) THEN
    o := o || pg_catalog.jsonb_build_object(k,v);
   ELSIF p_strict THEN RAISE EXCEPTION 'Ungültiger Wert für %', k USING ERRCODE='22023'; END IF;
   CONTINUE;
  END IF;
  v_slot := CASE WHEN k IN ('pose_profile','pose_card') THEN 'pose' ELSE k END;
  opt := v_slot IN ('head','top','coat','aura','eyefx');
  IF opt AND v='none' THEN o := o || pg_catalog.jsonb_build_object(k,'none'); CONTINUE; END IF;
  SELECT * INTO it FROM public.holo_items x WHERE x.key=v_slot||'_'||v AND x.slot=v_slot;
  IF it.key IS NULL OR NOT league_private.holo_has(p,it) THEN
   IF p_strict THEN
    IF it.key IS NULL THEN RAISE EXCEPTION 'Unbekannte Auswahl: %', pg_catalog.left(v,30) USING ERRCODE='22023'; END IF;
    RAISE EXCEPTION '«%» ist für dich noch nicht freigeschaltet', it.name USING ERRCODE='42501';
   END IF;
   CONTINUE;
  END IF;
  o := o || pg_catalog.jsonb_build_object(k,v);
 END LOOP;
 RETURN o;
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.holo_item_json(p uuid, it public.holo_items)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object('key',it.key,'slot',it.slot,'value',pg_catalog.substr(it.key,pg_catalog.char_length(it.slot)+2),'name',it.name,
  'rarity',it.rarity,'unlock',it.unlock,'price',it.price,'reward',CASE WHEN it.reward IS NULL THEN NULL ELSE league_private.holo_reward_label(it.reward) END,
  'owned',league_private.holo_has(p,it))
$fn$;

REVOKE ALL ON FUNCTION league_private.holo_reward_ok(uuid,jsonb), league_private.holo_reward_label(jsonb),
 league_private.holo_has(uuid,public.holo_items), league_private.holo_clean(uuid,jsonb,boolean),
 league_private.holo_item_json(uuid,public.holo_items) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Eigener Holo: Einstellung, Katalog mit Besitz, Bundles, Coins
CREATE OR REPLACE FUNCTION public.get_my_holo()
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); on_ boolean; shop boolean; cfg jsonb;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 on_ := league_private.flag_on('boxer_holo');
 IF NOT on_ AND me.role NOT IN ('admin','coach') THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 shop := league_private.flag_on('kampfgeist_shop') OR me.role='admin';
 IF shop THEN PERFORM league_private.kg_sync(me.id); END IF;
 SELECT x.config INTO cfg FROM public.holo_config x WHERE x.profile_id=me.id;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT on_,'shop',shop,'display_name',me.display_name,
  'coins',CASE WHEN shop THEN league_private.kg_balance(me.id) END,
  'saved',cfg IS NOT NULL,'config',league_private.holo_clean(me.id,cfg,false),
  'items',(SELECT pg_catalog.jsonb_agg(league_private.holo_item_json(me.id,i) ORDER BY i.sort_order, i.key) FROM public.holo_items i WHERE i.is_active),
  'bundles',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('key',b.key,'name',b.name,'description',b.description,'price',b.price,'items',pg_catalog.to_jsonb(b.items),
     'value',(SELECT coalesce(sum(i.price),0) FROM public.holo_items i WHERE i.key=ANY(b.items)),
     'owned_all',NOT EXISTS (SELECT 1 FROM public.holo_items i WHERE i.key=ANY(b.items) AND NOT league_private.holo_has(me.id,i))) ORDER BY b.sort_order, b.key)
   FROM public.holo_bundles b WHERE b.is_active),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.save_my_holo(p_config jsonb)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); c jsonb;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('boxer_holo') AND me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Der Boxer-Holo ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_config IS NULL OR pg_catalog.octet_length(p_config::text)>4000 THEN RAISE EXCEPTION 'Ungültige Einstellung' USING ERRCODE='22023'; END IF;
 c := league_private.holo_clean(me.id,p_config,true);
 INSERT INTO public.holo_config(profile_id,config) VALUES (me.id,c)
 ON CONFLICT (profile_id) DO UPDATE SET config=EXCLUDED.config, updated_at=now();
 RETURN c;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.buy_holo_item(p_key text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); it public.holo_items; bal integer; lid bigint;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT (league_private.flag_on('boxer_holo') OR me.role='admin') OR NOT (league_private.flag_on('kampfgeist_shop') OR me.role='admin') THEN
  RAISE EXCEPTION 'Der Shop ist noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 SELECT * INTO it FROM public.holo_items x WHERE x.key=p_key AND x.is_active;
 IF NOT FOUND OR it.unlock<>'shop' THEN RAISE EXCEPTION 'Dieses Item gibt es nicht im Shop' USING ERRCODE='22023'; END IF;
 PERFORM league_private.kg_sync(me.id);  -- nimmt auch die Sperre für dieses Konto
 IF EXISTS (SELECT 1 FROM public.holo_owned o WHERE o.profile_id=me.id AND o.item_key=it.key) THEN
  RAISE EXCEPTION 'Das hast du schon' USING ERRCODE='23505';
 END IF;
 bal := league_private.kg_balance(me.id);
 IF bal<it.price THEN RAISE EXCEPTION 'Zu wenig Coins: dir fehlen noch %', it.price-bal USING ERRCODE='22023'; END IF;
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note,created_by)
 VALUES (me.id,-it.price,'purchase','holo:'||it.key,'Boxer-Holo: '||it.name,me.id) RETURNING id INTO lid;
 INSERT INTO public.holo_owned(profile_id,item_key,source,ledger_id) VALUES (me.id,it.key,'shop',lid);
 RETURN pg_catalog.jsonb_build_object('key',it.key,'name',it.name,'price',it.price,'balance',bal-it.price);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.buy_holo_bundle(p_key text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); b public.holo_bundles; bal integer; lid bigint; n integer;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT (league_private.flag_on('boxer_holo') OR me.role='admin') OR NOT (league_private.flag_on('kampfgeist_shop') OR me.role='admin') THEN
  RAISE EXCEPTION 'Der Shop ist noch nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 SELECT * INTO b FROM public.holo_bundles x WHERE x.key=p_key AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Dieses Bundle gibt es nicht' USING ERRCODE='22023'; END IF;
 PERFORM league_private.kg_sync(me.id);
 IF NOT EXISTS (SELECT 1 FROM public.holo_items i WHERE i.key=ANY(b.items) AND i.is_active AND NOT league_private.holo_has(me.id,i)) THEN
  RAISE EXCEPTION 'Du hast schon alles aus diesem Bundle' USING ERRCODE='23505';
 END IF;
 bal := league_private.kg_balance(me.id);
 IF bal<b.price THEN RAISE EXCEPTION 'Zu wenig Coins: dir fehlen noch %', b.price-bal USING ERRCODE='22023'; END IF;
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note,created_by)
 VALUES (me.id,-b.price,'purchase','holo_bundle:'||b.key,'Boxer-Holo-Bundle: '||b.name,me.id) RETURNING id INTO lid;
 INSERT INTO public.holo_owned(profile_id,item_key,source,ledger_id)
 SELECT me.id,i.key,'bundle',lid FROM public.holo_items i WHERE i.key=ANY(b.items) AND i.is_active
 ON CONFLICT (profile_id,item_key) DO NOTHING;
 GET DIAGNOSTICS n = ROW_COUNT;
 RETURN pg_catalog.jsonb_build_object('key',b.key,'name',b.name,'price',b.price,'new_items',n,'balance',bal-b.price);
END;
$fn$;

-- Holos anderer (Profil, Karten, Vergleich): nur angemeldet, nur sichtbare Profile (Trainer sehen alle), nur gespeicherte Holos.
CREATE OR REPLACE FUNCTION public.get_holo_looks(p_display_names text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); staff boolean;
BEGIN
 IF me.id IS NULL THEN RETURN '{}'::jsonb; END IF;
 staff := me.role IN ('admin','coach');
 IF NOT league_private.flag_on('boxer_holo') AND NOT staff THEN RETURN '{}'::jsonb; END IF;
 IF coalesce(pg_catalog.cardinality(p_display_names),0)>50 THEN RAISE EXCEPTION 'Höchstens 50 Namen auf einmal' USING ERRCODE='22023'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_object_agg(p.display_name, league_private.holo_clean(p.id,h.config,false))
  FROM public.profiles p JOIN public.holo_config h ON h.profile_id=p.id
  WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')
   AND pg_catalog.lower(p.display_name) IN (SELECT pg_catalog.lower(pg_catalog.btrim(n)) FROM pg_catalog.unnest(p_display_names) n)
   AND (p.id=me.id OR staff OR p.is_listed IS TRUE)
   AND (SELECT count(*) FROM public.profiles q WHERE pg_catalog.lower(q.display_name)=pg_catalog.lower(p.display_name) AND q.is_active AND q.archived_at IS NULL)=1),'{}'::jsonb);
END;
$fn$;

-- Admin: Item als Belohnung oder Ausgleich schenken (ohne Coins).
CREATE OR REPLACE FUNCTION public.admin_grant_holo_item(p_profile_id uuid, p_key text, p_note text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); it public.holo_items; n text; cnt integer;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 SELECT * INTO it FROM public.holo_items x WHERE x.key=p_key AND x.is_active;
 IF NOT FOUND OR it.unlock='start' THEN RAISE EXCEPTION 'Dieses Item kann man nicht schenken' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=p_profile_id AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')) THEN
  RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023';
 END IF;
 n := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF n IS NULL OR pg_catalog.char_length(n)>200 THEN RAISE EXCEPTION 'Bitte kurz begründen (höchstens 200 Zeichen)' USING ERRCODE='22023'; END IF;
 INSERT INTO public.holo_owned(profile_id,item_key,source,note) VALUES (p_profile_id,it.key,'admin',n)
 ON CONFLICT (profile_id,item_key) DO NOTHING;
 GET DIAGNOSTICS cnt = ROW_COUNT;
 RETURN pg_catalog.jsonb_build_object('key',it.key,'name',it.name,'granted',cnt>0);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_holo(), public.save_my_holo(jsonb), public.buy_holo_item(text), public.buy_holo_bundle(text),
 public.get_holo_looks(text[]), public.admin_grant_holo_item(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_holo(), public.save_my_holo(jsonb), public.buy_holo_item(text), public.buy_holo_bundle(text),
 public.get_holo_looks(text[]), public.admin_grant_holo_item(uuid,text,text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
