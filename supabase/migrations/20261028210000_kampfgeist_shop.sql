-- Etappe 4 (28.10.2026, Owner-Auftrag): Kampfgeist-Coins, grosser Shop (Anime-Kampfgeist, eigene Designs), Inventar, Level-Roadmap.
-- Owner-Entscheide: Startguthaben 100 Coins; 10 Coins pro bestätigtem Training, auch rückwirkend für bisherige Trainings;
-- Quest-Coins aus Etappe 3 werden gutgeschrieben; Level-Maximum 99 (Ränge F–A je 10 Levels, S = Level 61–99);
-- Stilwelt Anime-Kampfgeist; keine Echtgeld-Käufe, keine Zufallsboxen; auch das Admin-Konto verdient Coins normal.
-- * Coins entstehen nur über das Coin-Buch (kg_ledger, nur Anhängen). Gutschriften werden beim Öffnen von Shop/Übersicht
--   aus bestätigten Trainings und abgeholten Quests nachgetragen (idempotent über Unique-Schlüssel). Es gibt keine Trigger auf
--   bestehenden Tabellen; Trainings, Punkte und EXP werden nicht verändert.
-- * Flag kampfgeist_shop bleibt AUS. Ohne Flag sieht nur der Admin eine Vorschau (nur lesen).
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('league_private.active_viewer()') IS NULL OR to_regprocedure('league_private.flag_on(text)') IS NULL
    OR to_regclass('public.quest_claims') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: zuerst Etappe 1 bis 3 anwenden';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('kampfgeist_shop','Kampfgeist-Shop (Coins, Shop, Inventar, Level-Roadmap)',false)
ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.kg_settings(
 id smallint PRIMARY KEY DEFAULT 1 CHECK (id=1),
 start_coins integer NOT NULL DEFAULT 100 CHECK (start_coins BETWEEN 0 AND 5000),
 coins_per_training integer NOT NULL DEFAULT 10 CHECK (coins_per_training BETWEEN 0 AND 500),
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES public.profiles(id)
);
INSERT INTO public.kg_settings(id) VALUES (1) ON CONFLICT(id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.kg_items(
 key text PRIMARY KEY CHECK (key ~ '^[a-z][a-z0-9_]{1,40}$'),
 category text NOT NULL CHECK (category IN ('avatar','aura','banner','rahmen','titel','handschuhe')),
 name text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 60),
 description text CHECK (description IS NULL OR char_length(description)<=200),
 rarity text NOT NULL CHECK (rarity IN ('common','rare','epic','leg','myth')),
 min_rank text NOT NULL CHECK (min_rank IN ('F','E','D','C','B','A','S')),
 unlock text NOT NULL CHECK (unlock IN ('start','rank','shop')),
 price integer CHECK (price IS NULL OR price BETWEEN 10 AND 20000),
 design jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(design)='object'),
 sort_order integer NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true,
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES public.profiles(id),
 CHECK ((unlock='shop') = (price IS NOT NULL)),
 CHECK (unlock<>'start' OR min_rank='F')
);

CREATE TABLE IF NOT EXISTS public.kg_ledger(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 amount integer NOT NULL CHECK (amount<>0 AND amount BETWEEN -100000 AND 100000),
 reason text NOT NULL CHECK (reason IN ('start','training','training_fix','quest','purchase','admin')),
 ref text NOT NULL CHECK (char_length(ref) BETWEEN 1 AND 120),
 note text CHECK (note IS NULL OR char_length(note)<=200),
 created_by uuid REFERENCES public.profiles(id),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(profile_id, reason, ref)
);
CREATE INDEX IF NOT EXISTS kg_ledger_profile_idx ON public.kg_ledger(profile_id, id DESC);

CREATE TABLE IF NOT EXISTS public.kg_inventory(
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 item_key text NOT NULL REFERENCES public.kg_items(key),
 price_paid integer NOT NULL CHECK (price_paid>=0),
 ledger_id bigint UNIQUE REFERENCES public.kg_ledger(id),
 acquired_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(profile_id, item_key)
);

CREATE TABLE IF NOT EXISTS public.kg_equipped(
 profile_id uuid PRIMARY KEY REFERENCES public.profiles(id),
 avatar text REFERENCES public.kg_items(key), aura text REFERENCES public.kg_items(key),
 banner text REFERENCES public.kg_items(key), rahmen text REFERENCES public.kg_items(key),
 titel text REFERENCES public.kg_items(key), handschuhe text REFERENCES public.kg_items(key),
 updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kg_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_equipped ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kg_settings, public.kg_items, public.kg_ledger, public.kg_inventory, public.kg_equipped FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Katalog: 114 Items, alle eigene Designs (Stil Anime-Kampfgeist). Preise nach Rang gestaffelt.
INSERT INTO public.kg_items(key,category,name,description,rarity,min_rank,unlock,price,design,sort_order) VALUES
-- Avatare: Start
 ('a_kenji','avatar','Kenji · Glutfaust','Gibt nie auf, auch nicht in Runde zwölf.','common','F','start',NULL,'{"hair":"spiky","hc":"#2a1616","skin":"#e8b48a","eye":"#ff5a1f","hb":"#f6f0e4"}',100),
 ('a_zara','avatar','Zara · Doppelschlag','Zwei Schläge, bevor du einmal blinzelst.','common','F','start',NULL,'{"hair":"buns","hc":"#1a100c","skin":"#6b4027","eye":"#ffb020"}',101),
 ('a_luca','avatar','Luca · Ruhepuls','Bleibt ruhig, wenn es laut wird.','common','F','start',NULL,'{"hair":"buzz","hc":"#3b2a1e","skin":"#c99069","eye":"#5fb27f"}',102),
 ('a_mei','avatar','Mei · Kirschschritt','Leichtfüssig wie ein Blatt im Wind.','common','F','start',NULL,'{"hair":"bob","hc":"#151018","skin":"#f3d2b8","eye":"#ff9cc0"}',103),
-- Avatare: Shop F
 ('a_lina','avatar','Lina · Funkenschritt','Ihre Beinarbeit sprüht Funken.','common','F','shop',200,'{"hair":"pony","hc":"#3a2418","skin":"#f1c7a3","eye":"#ff8a3c","hb":"#ff5a1f"}',110),
 ('a_malik','avatar','Malik · Steinherz','Ruhig wie ein Fels, hart wie einer.','common','F','shop',200,'{"hair":"buzz","hc":"#140d0a","skin":"#7a4a2e","eye":"#c7a27a","beard":true}',111),
 ('a_sora','avatar','Sora · Windjab','Der Jab kommt, bevor der Wind dreht.','common','F','shop',250,'{"hair":"spiky","hc":"#2c3e8f","skin":"#f3d2b8","eye":"#7fd0ff","hb":"#4fa3ff"}',112),
 ('a_ivo','avatar','Ivo · Bergkinn','Aus den Tessiner Bergen, steckt alles weg.','common','F','shop',250,'{"hair":"undercut","hc":"#6b3e1f","skin":"#e2b08a","eye":"#5fb27f"}',113),
 ('a_nia','avatar','Nia · Wirbelkonter','Dreht sich weg und ist schon wieder da.','rare','F','shop',300,'{"hair":"afro","hc":"#1d120c","skin":"#5e3822","eye":"#ffcc33","hb":"#f2c14e"}',114),
-- Avatare: E
 ('a_tomas','avatar','Tomás · Glutläufer','Läuft jeden Morgen, egal bei welchem Wetter.','rare','E','shop',450,'{"hair":"curly","hc":"#2b1a10","skin":"#b97a52","eye":"#ff8a3c"}',120),
 ('a_mira','avatar','Mira · Sturmauge','Liest jeden Schlag eine Sekunde im Voraus.','rare','E','shop',500,'{"hair":"pony","hc":"#24357a","skin":"#c98e64","eye":"#7fd0ff","hb":"#4fa3ff"}',121),
 ('a_yuki','avatar','Yuki · Frostkonter','Bleibt eiskalt und kontert im letzten Moment.','rare','E','shop',550,'{"hair":"bob","hc":"#dfe9ff","skin":"#f3d2b8","eye":"#55e6ff","hb":"#55e6ff"}',122),
 ('a_amara','avatar','Amara · Donnerfaust','Wenn sie trifft, hört man es im ganzen Gym.','rare','E','shop',600,'{"hair":"braids","hc":"#120b08","skin":"#4a2c1a","eye":"#b874ff"}',123),
 ('a_rico','avatar','Rico · Konterkönig','Wartet auf deinen Fehler. Und lächelt.','rare','E','shop',600,'{"hair":"mohawk","hc":"#c43b2b","skin":"#d9a27a","eye":"#ffb020"}',124),
-- Avatare: D
 ('a_nova','avatar','Nova · Lichtschritt','Ihre Beinarbeit hinterlässt Lichtspuren.','epic','D','shop',900,'{"hair":"long","hc":"#f2d27a","skin":"#f0c49c","eye":"#ffcc33"}',130),
 ('a_bruno','avatar','Bruno · Bergbrecher','Ein Haken, ein Erdbeben.','epic','D','shop',1000,'{"hair":"mohawk","hc":"#8a2a1e","skin":"#8d5a3b","eye":"#ffb020","beard":true}',131),
 ('a_selin','avatar','Selin · Mondschritt','Trainiert, wenn alle anderen schlafen.','epic','D','shop',1000,'{"hair":"long","hc":"#cfd6e6","skin":"#d9a27a","eye":"#b874ff"}',132),
 ('a_jin','avatar','Jin · Stahlblick','Ein Blick, und der Gegner zögert.','epic','D','shop',1100,'{"hair":"undercut","hc":"#0f1424","skin":"#f0c9a8","eye":"#4fc3ff","glow":true}',133),
-- Avatare: C
 ('a_taro','avatar','Taro · Eisenkinn','Steckt alles weg und lächelt dabei.','epic','C','shop',1200,'{"hair":"buzz","hc":"#3b2a1e","skin":"#d9a27a","eye":"#c7c7d6","scar":true}',140),
 ('a_kael','avatar','Kael · Nachtklinge','Niemand hat ihn je müde gesehen.','epic','C','shop',1300,'{"hair":"hood","hc":"#161b30","skin":"#cfa58a","eye":"#4fc3ff","glow":true}',141),
 ('a_leandra','avatar','Leandra · Feuersturm','Jede Runde heisser als die letzte.','epic','C','shop',1500,'{"hair":"long","hc":"#b3261e","skin":"#f1c7a3","eye":"#ff5a1f","glow":true,"marks":"#ff8a3c"}',142),
-- Avatare: B
 ('a_rhea','avatar','Rhea · Eisschatten','Ihr Blick friert den Gegner ein.','leg','B','shop',2000,'{"hair":"long","hc":"#e8f0ff","skin":"#e6c4ad","eye":"#b874ff","glow":true,"marks":"#b874ff"}',150),
 ('a_kenta','avatar','Kenta · Gewitterfaust','Wo er trainiert, riecht es nach Gewitter.','leg','B','shop',2200,'{"hair":"spiky","hc":"#eef3ff","skin":"#c98e64","eye":"#7fd0ff","glow":true,"marks":"#4fa3ff"}',151),
-- Avatare: A
 ('a_meister','avatar','Der alte Meister','Hatte schon hundert Champions an der Pratze.','leg','A','shop',2800,'{"hair":"bald","hc":"#e8e3d8","skin":"#c88f68","eye":"#a8a2bb","brow":"#e8e3d8","stache":true}',160),
 ('a_varn','avatar','Varn · Abgrundfaust','Kam aus der tiefsten Gewichtsklasse zurück.','leg','A','shop',3000,'{"hair":"mohawk","hc":"#2a1640","skin":"#3a2d44","eye":"#ff3d6e","glow":true,"marks":"#b874ff","scar":true}',161),
-- Avatare: S
 ('a_schatten','avatar','Der Schattenpartner','Dein Schatten aus dem Schattenboxen. Er wurde lebendig.','myth','S','shop',4500,'{"hair":"flame","hc":"#ff3d6e","skin":"#1c1628","eye":"#ff3d6e","shadow":true}',170),
 ('a_namenlos','avatar','Der Namenlose','Sein Name steht nirgends, nur seine Bilanz.','myth','S','shop',5000,'{"hair":"flame","hc":"#5b2bd6","skin":"#120f1c","eye":"#f2c14e","shadow":true,"marks":"#f2c14e"}',171),
-- Auren
 ('u_none','aura','Keine Aura',NULL,'common','F','start',NULL,'{}',200),
 ('u_glut','aura','Glut-Aura','Leise Glut, die nie ganz ausgeht.','common','F','shop',250,'{"g":"#ff5a1f,#ffb347,#ff2d00,#ffd27a,#ff5a1f","p":"#ff8a3c"}',210),
 ('u_wind','aura','Windhauch','Ein kühler Luftzug bei jedem Schritt.','common','F','shop',250,'{"g":"#c9f6ff,#7fd0ff,#ffffff,#4fa3ff,#c9f6ff","p":"#e6f4ff"}',211),
 ('u_frost','aura','Frost-Aura','Kälte, die den Gegner bremst.','rare','E','shop',450,'{"g":"#55e6ff,#ffffff,#2bb6ff,#c9f6ff,#55e6ff","p":"#c9f6ff","pulse":true}',220),
 ('u_smaragd','aura','Smaragdnebel','Grüner Nebel, ruhig und gefährlich.','rare','E','shop',500,'{"g":"#4fe0a6,#0e3b2c,#9cf5d0,#1f7a57,#4fe0a6","p":"#9cf5d0"}',221),
 ('u_kirsch','aura','Kirschblüten-Aura','Blüten fallen, wenn du dich bewegst.','rare','E','shop',600,'{"g":"#ff9cc0,#ffe3ee,#ff5f9e,#ffd1e2,#ff9cc0","petals":true}',222),
 ('u_sturm','aura','Sturm-Aura','Blitze zucken um deine Fäuste.','epic','D','shop',900,'{"g":"#4fa3ff,#e6f4ff,#2b5bd7,#bfe3ff,#4fa3ff","p":"#e6f4ff","pulse":true}',230),
 ('u_rauch','aura','Schattenrauch','Rauch, der dich verschluckt und wieder ausspuckt.','epic','D','shop',1000,'{"g":"#2b2f45,#6b4bd6,#14121f,#4fc3ff,#2b2f45","p":"#8f7bff"}',231),
 ('u_sonne','aura','Sonnenkern','Warm, hell, unaufhaltsam.','epic','C','shop',1400,'{"g":"#ffcc33,#fff3c4,#ff8a3c,#ffe08a,#ffcc33","p":"#fff3c4","pulse":true}',240),
 ('u_kalt','aura','Kälteblitz','Ein Blitz aus Eis.','epic','C','shop',1500,'{"g":"#4fc3ff,#0b1a3a,#cfefff,#2a5bd7,#4fc3ff","p":"#cfefff","pulse":true}',241),
 ('u_abgrund','aura','Abgrundfeuer','Feuer aus der Tiefe.','leg','B','shop',2200,'{"g":"#b874ff,#2a0b3a,#ff3d6e,#120f1c,#b874ff","p":"#d7a6ff","pulse":true}',250),
 ('u_limit','aura','Limit-Break-Aura','Alle Farben auf einmal. Grenze überschritten.','leg','B','shop',2400,'{"g":"#ffcc33,#ff3d6e,#b874ff,#4fa3ff,#4fe0a6,#ffcc33","p":"#ffcc33"}',251),
 ('u_drache','aura','Drachenatem','Rot und Gold, wie ein Drache im Ring.','leg','A','shop',3200,'{"g":"#ff3d3d,#ffcc33,#8a0f0f,#ffb020,#ff3d3d","p":"#ffcc33","pulse":true}',260),
 ('u_schatten','aura','Schattenflamme','Brennt dunkel und kalt.','myth','S','shop',4500,'{"g":"#ff3d6e,#2a0b3a,#b874ff,#0c0a13,#ff3d6e","p":"#ff3d6e","pulse":true}',270),
 ('u_leere','aura','Leere-Riss','Ein Riss in der Wirklichkeit, golden umrandet.','myth','S','shop',5000,'{"g":"#f2c14e,#0b0a12,#f2c14e,#3a2a10,#0b0a12,#f2c14e","p":"#f2c14e","pulse":true}',271),
-- Banner
 ('b_dojo','banner','Dojo bei Nacht',NULL,'common','F','start',NULL,'{"bn":"dojo"}',300),
 ('b_ring','banner','Ring-Seile','Dein Platz zwischen den Seilen.','common','F','shop',200,'{"bn":"ring"}',310),
 ('b_sunrise','banner','Sonnenaufgang-Lauf','Der erste Lauf des Tages.','common','F','shop',250,'{"bn":"sunrise"}',311),
 ('b_ember','banner','Glutfunken','Funken fliegen im dunklen Gym.','common','F','shop',300,'{"bn":"ember"}',312),
 ('b_storm','banner','Gewitterring','Ring unter Blitzen.','rare','E','shop',500,'{"bn":"storm"}',320),
 ('b_sakura','banner','Kirschblütenweg','Laufweg unter Blüten.','rare','E','shop',550,'{"bn":"sakura"}',321),
 ('b_rooftop','banner','Dach bei Abenddämmerung','Schattenboxen über der Stadt.','rare','E','shop',600,'{"bn":"rooftop"}',322),
 ('b_lake','banner','Lugano bei Nacht','Lichter am See, Berge im Dunkeln.','epic','D','shop',900,'{"bn":"lake"}',330),
 ('b_spot','banner','Arena-Scheinwerfer','Alle Augen auf dich.','epic','D','shop',1000,'{"bn":"spot"}',331),
 ('b_wasserfall','banner','Wasserfall-Training','Unter dem Wasserfall wird der Kopf frei.','epic','D','shop',1100,'{"bn":"waterfall"}',332),
 ('b_mitternacht','banner','Mitternachtssturm','Regen, Wind und ein Ziel.','epic','C','shop',1400,'{"bn":"midnight"}',340),
 ('b_speed','banner','Speedlines','Schneller als das Auge.','epic','C','shop',1600,'{"bn":"speed"}',341),
 ('b_shadow','banner','Schattenreich','Wo dein Schatten trainiert.','leg','B','shop',2000,'{"bn":"shadow"}',350),
 ('b_riss','banner','Riss im Raum','Etwas bricht durch.','leg','B','shop',2200,'{"bn":"rift"}',351),
 ('b_mond','banner','Kalter Mond','Gipfel unter dem Mond.','leg','A','shop',3000,'{"bn":"moon"}',360),
 ('b_gold','banner','Goldene Arena','Gold von oben, Applaus von allen Seiten.','leg','A','shop',3200,'{"bn":"gold"}',361),
 ('b_leere','banner','Die Leere','Nur für die Stärksten.','myth','S','shop',5000,'{"bn":"void"}',370),
-- Profilrahmen
 ('f_none','rahmen','Schlicht',NULL,'common','F','start',NULL,'{"fr":"none"}',400),
 ('f_linie','rahmen','Feine Linie','Schlicht mit goldenem Hauch.','common','F','shop',150,'{"fr":"linie"}',410),
 ('f_glut','rahmen','Glutrand','Ein Rand, der leise glüht.','common','F','shop',250,'{"fr":"glut"}',411),
 ('f_frost','rahmen','Frostkante','Eiskristalle am Rand.','rare','E','shop',450,'{"fr":"frost"}',420),
 ('f_kirsch','rahmen','Blütenkranz','Kirschblüten rundherum.','rare','E','shop',500,'{"fr":"kirsch"}',421),
 ('f_kalt','rahmen','Kaltes Leuchten','Blaues Leuchten wie ein Statusfenster.','epic','D','shop',900,'{"fr":"kalt"}',430),
 ('f_system','rahmen','Systemfenster','Als hätte das System dich ausgewählt.','epic','C','shop',1500,'{"fr":"system"}',440),
 ('f_blitz','rahmen','Blitzrand','Zuckende Blitze am Rand.','leg','B','shop',2000,'{"fr":"blitz"}',450),
 ('f_abgrund','rahmen','Abgrund','Violett pulsierend.','leg','A','shop',2800,'{"fr":"abgrund"}',460),
 ('f_srang','rahmen','Rang S · Gold','Goldener Glanz, der über den Rand wandert.','myth','S','shop',4500,'{"fr":"srang"}',470),
 ('f_rang_e','rahmen','Emblem Rang E','Belohnung für Rang E (Prospect).','rare','E','rank',NULL,'{"fr":"rank","rk":"E"}',480),
 ('f_rang_d','rahmen','Emblem Rang D','Belohnung für Rang D (Contender).','rare','D','rank',NULL,'{"fr":"rank","rk":"D"}',481),
 ('f_rang_c','rahmen','Emblem Rang C','Belohnung für Rang C (Challenger).','epic','C','rank',NULL,'{"fr":"rank","rk":"C"}',482),
 ('f_rang_b','rahmen','Emblem Rang B','Belohnung für Rang B (Elite Fighter).','epic','B','rank',NULL,'{"fr":"rank","rk":"B"}',483),
 ('f_rang_a','rahmen','Emblem Rang A','Belohnung für Rang A (Champion).','leg','A','rank',NULL,'{"fr":"rank","rk":"A"}',484),
 ('f_rang_s','rahmen','Emblem Rang S','Belohnung für Rang S (Legend).','myth','S','rank',NULL,'{"fr":"rank","rk":"S"}',485),
-- Titel
 ('t_rookie','titel','Rookie','Jeder fängt hier an.','common','F','start',NULL,'{}',500),
 ('t_frueh','titel','Frühaufsteher','Vor allen anderen im Gym.','common','F','shop',100,'{}',510),
 ('t_schweiss','titel','Schweiss & Ehre',NULL,'common','F','shop',150,'{}',511),
 ('t_jab','titel','Jab-Lehrling',NULL,'common','F','shop',150,'{}',512),
 ('t_deckung','titel','Deckung hoch!',NULL,'common','F','shop',150,'{}',513),
 ('t_ring','titel','Ringgeist',NULL,'rare','E','shop',350,'{}',520),
 ('t_runde','titel','Noch eine Runde',NULL,'rare','E','shop',350,'{}',521),
 ('t_konter','titel','Kontermeister',NULL,'rare','E','shop',450,'{}',522),
 ('t_unerm','titel','Der Unermüdliche',NULL,'rare','E','shop',450,'{}',523),
 ('t_wirbel','titel','Wirbelwind',NULL,'epic','D','shop',700,'{}',530),
 ('t_eisen','titel','Eisenkinn',NULL,'epic','D','shop',800,'{}',531),
 ('t_runden','titel','Herr der Runden',NULL,'epic','D','shop',900,'{}',532),
 ('t_kalt','titel','Kältester Konter',NULL,'epic','C','shop',1200,'{}',540),
 ('t_feuer','titel','Das Feuer brennt',NULL,'epic','C','shop',1200,'{}',541),
 ('t_schatten','titel','Der aus dem Schatten',NULL,'leg','B','shop',1800,'{}',550),
 ('t_sturm','titel','Sturm im Ring',NULL,'leg','B','shop',1800,'{}',551),
 ('t_unbez','titel','Unbezwungen',NULL,'leg','A','shop',2800,'{}',560),
 ('t_entf','titel','Kampfgeist entfesselt',NULL,'leg','A','shop',3000,'{}',561),
 ('t_jenseits','titel','Jenseits des Limits',NULL,'myth','S','shop',4500,'{}',570),
 ('t_prospect','titel','Prospect','Belohnung für Rang E.','rare','E','rank',NULL,'{}',580),
 ('t_contender','titel','Contender','Belohnung für Rang D.','rare','D','rank',NULL,'{}',581),
 ('t_challenger','titel','Challenger','Belohnung für Rang C.','epic','C','rank',NULL,'{}',582),
 ('t_elite','titel','Elite Fighter','Belohnung für Rang B.','epic','B','rank',NULL,'{}',583),
 ('t_champion','titel','Champion','Belohnung für Rang A.','leg','A','rank',NULL,'{}',584),
 ('t_legend','titel','Legend','Belohnung für Rang S.','myth','S','rank',NULL,'{}',585),
-- Handschuhe
 ('g_rot','handschuhe','Klassik Rot',NULL,'common','F','start',NULL,'{"base":"#d8282f","acc":"#ffffff","cuff":"#f6f0e4","pat":"none"}',600),
 ('g_blau','handschuhe','Klassik Blau',NULL,'common','F','shop',150,'{"base":"#1f4fd8","acc":"#ffffff","cuff":"#f6f0e4","pat":"none"}',610),
 ('g_weiss','handschuhe','Schneeweiss',NULL,'common','F','shop',150,'{"base":"#f2f2f5","acc":"#c9ced8","cuff":"#d8282f","pat":"none"}',611),
 ('g_glut','handschuhe','Glut',NULL,'common','F','shop',300,'{"base":"#2a0e08","acc":"#ff5a1f","cuff":"#ffb347","pat":"flame"}',612),
 ('g_kirsch','handschuhe','Kirschblüte',NULL,'rare','E','shop',450,'{"base":"#ffd1e2","acc":"#ff5f9e","cuff":"#ffffff","pat":"petal"}',620),
 ('g_jade','handschuhe','Jade',NULL,'rare','E','shop',450,'{"base":"#0e6b4f","acc":"#9cf5d0","cuff":"#f6f0e4","pat":"petal"}',621),
 ('g_tiger','handschuhe','Tigerkralle',NULL,'rare','E','shop',550,'{"base":"#ffb020","acc":"#16131f","cuff":"#16131f","pat":"tiger"}',622),
 ('g_sturm','handschuhe','Sturmklinge',NULL,'epic','D','shop',900,'{"base":"#1b3f9e","acc":"#e6f4ff","cuff":"#4fa3ff","pat":"bolt"}',630),
 ('g_frost','handschuhe','Frostbiss',NULL,'epic','D','shop',900,'{"base":"#cfefff","acc":"#2bb6ff","cuff":"#ffffff","pat":"crack"}',631),
 ('g_obsidian','handschuhe','Obsidian',NULL,'epic','C','shop',1400,'{"base":"#15101f","acc":"#b874ff","cuff":"#4fc3ff","pat":"crack"}',640),
 ('g_gold','handschuhe','Champion-Gold',NULL,'leg','B','shop',2200,'{"base":"#ffcc33","acc":"#fff3c4","cuff":"#b37a00","pat":"star"}',650),
 ('g_drache','handschuhe','Drachenschuppe',NULL,'leg','A','shop',3000,'{"base":"#8a0f0f","acc":"#ffcc33","cuff":"#ffb020","pat":"flame"}',660),
 ('g_schatten','handschuhe','Schattenfaust',NULL,'myth','S','shop',4000,'{"base":"#171021","acc":"#ff3d6e","cuff":"#b874ff","pat":"flame"}',670),
 ('g_leere','handschuhe','Leerenfaust',NULL,'myth','S','shop',4500,'{"base":"#0b0a12","acc":"#f2c14e","cuff":"#f2c14e","pat":"crack"}',671)
ON CONFLICT(key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen (nicht aufrufbar für Clients)
CREATE OR REPLACE FUNCTION league_private.kg_exp(p uuid)
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT coalesce(sum(t.exp),0)::bigint FROM public.point_transactions t WHERE t.boxer_id=p
$fn$;

-- Gleiche Formel wie boxer-profile.js / takeover-gamification.js, Maximum Level 99.
CREATE OR REPLACE FUNCTION league_private.kg_level(xp bigint)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT LEAST(99, GREATEST(0, floor((sqrt(49+0.32*GREATEST(xp,0))-7)/2))::integer + 1)
$fn$;

CREATE OR REPLACE FUNCTION league_private.kg_rank_idx(p_level integer)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$ SELECT LEAST(6, GREATEST(0,(p_level-1)/10)) $fn$;

CREATE OR REPLACE FUNCTION league_private.kg_rank_of(r text)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$ SELECT array_position(ARRAY['F','E','D','C','B','A','S'], r)-1 $fn$;

-- Coin-Buch nachtragen: Startguthaben, bestätigte Trainings (auch rückwirkend), Korrekturen, Quest-Coins.
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
 -- Training nicht mehr bestätigt (oder wieder bestätigt): Differenz als Korrektur buchen.
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note)
 SELECT p, x.want-x.have, 'training_fix', x.base||':'||(x.fixes+1)::text,
        CASE WHEN x.want>x.have THEN 'Training wieder bestätigt' ELSE 'Training nicht mehr bestätigt' END
 FROM (SELECT g.base, g.have, g.fixes,
         CASE WHEN EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.id::text=g.base AND s.boxer_id=p AND s.status='approved')
              THEN g.credit ELSE 0 END AS want
       FROM (SELECT b.base, sum(b.amount)::integer AS have, count(*) FILTER (WHERE b.reason='training_fix')::integer AS fixes,
               coalesce(max(b.amount) FILTER (WHERE b.reason='training'),0)::integer AS credit
             FROM (SELECT pg_catalog.split_part(l.ref,':',1) AS base, l.amount, l.reason
                   FROM public.kg_ledger l WHERE l.profile_id=p AND l.reason IN ('training','training_fix')) b
             GROUP BY b.base) g) x
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

CREATE OR REPLACE FUNCTION league_private.kg_balance(p uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT coalesce(sum(l.amount),0)::integer FROM public.kg_ledger l WHERE l.profile_id=p
$fn$;

CREATE OR REPLACE FUNCTION league_private.kg_owns(p uuid, it public.kg_items, p_rank_idx integer)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT it.unlock='start'
     OR (it.unlock='rank' AND p_rank_idx>=league_private.kg_rank_of(it.min_rank))
     OR EXISTS (SELECT 1 FROM public.kg_inventory i WHERE i.profile_id=p AND i.item_key=it.key)
$fn$;

CREATE OR REPLACE FUNCTION league_private.kg_item_json(it public.kg_items)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT CASE WHEN it.key IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('key',it.key,'category',it.category,'name',it.name,
  'description',it.description,'rarity',it.rarity,'min_rank',it.min_rank,'unlock',it.unlock,'price',it.price,'design',it.design) END
$fn$;

-- Ausgerüstetes Aussehen (Fallback: Startitems), aufgelöst mit Design.
CREATE OR REPLACE FUNCTION league_private.kg_look(p uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE e public.kg_equipped; lvl integer := league_private.kg_level(league_private.kg_exp(p)); r jsonb := '{}'::jsonb; slot text; k text; it public.kg_items;
 defaults jsonb := '{"avatar":"a_kenji","aura":"u_none","banner":"b_dojo","rahmen":"f_none","titel":"t_rookie","handschuhe":"g_rot"}';
BEGIN
 SELECT * INTO e FROM public.kg_equipped x WHERE x.profile_id=p;
 FOREACH slot IN ARRAY ARRAY['avatar','aura','banner','rahmen','titel','handschuhe'] LOOP
  k := CASE slot WHEN 'avatar' THEN e.avatar WHEN 'aura' THEN e.aura WHEN 'banner' THEN e.banner
                 WHEN 'rahmen' THEN e.rahmen WHEN 'titel' THEN e.titel ELSE e.handschuhe END;
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

REVOKE ALL ON FUNCTION league_private.kg_exp(uuid), league_private.kg_level(bigint), league_private.kg_rank_idx(integer),
 league_private.kg_rank_of(text), league_private.kg_sync(uuid), league_private.kg_balance(uuid),
 league_private.kg_owns(uuid,public.kg_items,integer), league_private.kg_item_json(public.kg_items), league_private.kg_look(uuid)
 FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPCs
CREATE OR REPLACE FUNCTION public.get_my_kampfgeist(p_full boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); on_ boolean := league_private.flag_on('kampfgeist_shop');
 xp bigint; lvl integer; ri integer; st public.kg_settings;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT on_ AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 IF on_ THEN PERFORM league_private.kg_sync(me.id); END IF;
 xp := league_private.kg_exp(me.id); lvl := league_private.kg_level(xp); ri := league_private.kg_rank_idx(lvl);
 SELECT * INTO st FROM public.kg_settings WHERE id=1;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT on_,'can_buy',on_,
  'settings',pg_catalog.jsonb_build_object('start_coins',st.start_coins,'coins_per_training',st.coins_per_training),
  'wallet',pg_catalog.jsonb_build_object('balance',league_private.kg_balance(me.id),
    'earned',(SELECT coalesce(sum(l.amount) FILTER (WHERE l.amount>0),0) FROM public.kg_ledger l WHERE l.profile_id=me.id),
    'spent',(SELECT coalesce(-sum(l.amount) FILTER (WHERE l.reason='purchase'),0) FROM public.kg_ledger l WHERE l.profile_id=me.id),
    'quest_pending',(SELECT coalesce(sum(q.coins),0) FROM public.quest_claims q WHERE q.profile_id=me.id AND q.coins_credited_at IS NULL)),
  'level',pg_catalog.jsonb_build_object('exp',xp,'level',lvl,'rank',(ARRAY['F','E','D','C','B','A','S'])[ri+1],'rank_idx',ri),
  'look',league_private.kg_look(me.id))
 || CASE WHEN p_full IS FALSE THEN '{}'::jsonb ELSE pg_catalog.jsonb_build_object(
  'items',coalesce((SELECT pg_catalog.jsonb_agg(league_private.kg_item_json(it) || pg_catalog.jsonb_build_object(
     'owned',league_private.kg_owns(me.id,it,ri),'rank_ok',ri>=league_private.kg_rank_of(it.min_rank),'is_active',it.is_active)
     ORDER BY it.sort_order, it.key)
    FROM public.kg_items it WHERE it.is_active OR EXISTS (SELECT 1 FROM public.kg_inventory i WHERE i.profile_id=me.id AND i.item_key=it.key)),'[]'::jsonb),
  'history',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('amount',h.amount,'reason',h.reason,'note',h.note,'created_at',h.created_at) ORDER BY h.id DESC)
    FROM (SELECT * FROM public.kg_ledger l WHERE l.profile_id=me.id ORDER BY l.id DESC LIMIT 40) h),'[]'::jsonb)) END;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.buy_kg_item(p_item_key text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); it public.kg_items; ri integer; bal integer; lid bigint;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RAISE EXCEPTION 'Der Shop ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 SELECT * INTO it FROM public.kg_items x WHERE x.key=p_item_key AND x.is_active;
 IF NOT FOUND OR it.unlock<>'shop' THEN RAISE EXCEPTION 'Dieses Item gibt es nicht im Shop' USING ERRCODE='22023'; END IF;
 PERFORM league_private.kg_sync(me.id);  -- nimmt auch die Sperre für dieses Konto
 ri := league_private.kg_rank_idx(league_private.kg_level(league_private.kg_exp(me.id)));
 IF ri<league_private.kg_rank_of(it.min_rank) THEN RAISE EXCEPTION 'Erst ab Rang % erhältlich', it.min_rank USING ERRCODE='22023'; END IF;
 IF EXISTS (SELECT 1 FROM public.kg_inventory i WHERE i.profile_id=me.id AND i.item_key=it.key) THEN
  RAISE EXCEPTION 'Dieses Item hast du schon' USING ERRCODE='23505';
 END IF;
 bal := league_private.kg_balance(me.id);
 IF bal<it.price THEN RAISE EXCEPTION 'Zu wenig Coins: dir fehlen noch %', it.price-bal USING ERRCODE='22023'; END IF;
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note,created_by)
 VALUES (me.id,-it.price,'purchase',it.key,'Gekauft: '||it.name,me.id) RETURNING id INTO lid;
 INSERT INTO public.kg_inventory(profile_id,item_key,price_paid,ledger_id) VALUES (me.id,it.key,it.price,lid);
 RETURN pg_catalog.jsonb_build_object('key',it.key,'name',it.name,'price',it.price,'balance',bal-it.price);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.equip_kg_item(p_slot text, p_item_key text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); it public.kg_items; ri integer;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RAISE EXCEPTION 'Der Shop ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_slot IS NULL OR p_slot NOT IN ('avatar','aura','banner','rahmen','titel','handschuhe') THEN RAISE EXCEPTION 'Unbekannter Platz' USING ERRCODE='22023'; END IF;
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
  updated_at=now()
 WHERE x.profile_id=me.id;
 RETURN pg_catalog.jsonb_build_object('look',league_private.kg_look(me.id));
END;
$fn$;

-- Aussehen eines anderen Boxers (Profilseite). Nur für Angemeldete, nur bei eingeschaltetem Shop (Admin: Vorschau).
CREATE OR REPLACE FUNCTION public.get_kg_look(p_display_name text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles; n integer;
BEGIN
 IF me.id IS NULL THEN RETURN NULL; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') AND me.role<>'admin' THEN RETURN NULL; END IF;
 SELECT count(*) INTO n FROM public.profiles p WHERE pg_catalog.lower(p.display_name)=pg_catalog.lower(pg_catalog.btrim(coalesce(p_display_name,'')))
   AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 IF n<>1 THEN RETURN NULL; END IF;
 SELECT * INTO t FROM public.profiles p WHERE pg_catalog.lower(p.display_name)=pg_catalog.lower(pg_catalog.btrim(p_display_name))
   AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 IF t.id<>me.id AND me.role NOT IN ('admin','coach') AND t.is_listed IS NOT TRUE THEN RETURN NULL; END IF;
 RETURN league_private.kg_look(t.id) || pg_catalog.jsonb_build_object('name',t.display_name);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_kg_overview()
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); st public.kg_settings; pid uuid; on_ boolean := league_private.flag_on('kampfgeist_shop');
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 IF on_ THEN
  FOR pid IN SELECT p.id FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL ORDER BY p.id LOOP
   PERFORM league_private.kg_sync(pid);
  END LOOP;
 END IF;
 SELECT * INTO st FROM public.kg_settings WHERE id=1;
 RETURN pg_catalog.jsonb_build_object('enabled',on_,
  'settings',pg_catalog.jsonb_build_object('start_coins',st.start_coins,'coins_per_training',st.coins_per_training),
  'wallets',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,'role',p.role,
     'balance',league_private.kg_balance(p.id),
     'earned',(SELECT coalesce(sum(l.amount) FILTER (WHERE l.amount>0),0) FROM public.kg_ledger l WHERE l.profile_id=p.id),
     'spent',(SELECT coalesce(-sum(l.amount) FILTER (WHERE l.reason='purchase'),0) FROM public.kg_ledger l WHERE l.profile_id=p.id),
     'items',(SELECT count(*) FROM public.kg_inventory i WHERE i.profile_id=p.id),
     'level',league_private.kg_level(league_private.kg_exp(p.id)),
     'preview_coins',CASE WHEN on_ THEN NULL ELSE st.start_coins + st.coins_per_training*(SELECT count(*) FROM public.training_submissions s WHERE s.boxer_id=p.id AND s.status='approved')
       + (SELECT coalesce(sum(q.coins),0) FROM public.quest_claims q WHERE q.profile_id=p.id) END)
     ORDER BY pg_catalog.lower(p.display_name))
   FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL),'[]'::jsonb),
  'items',coalesce((SELECT pg_catalog.jsonb_agg(league_private.kg_item_json(it) || pg_catalog.jsonb_build_object('is_active',it.is_active,
     'owners',(SELECT count(*) FROM public.kg_inventory i WHERE i.item_key=it.key)) ORDER BY it.sort_order, it.key) FROM public.kg_items it),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_adjust_coins(p_profile_id uuid, p_amount integer, p_note text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles; note text := pg_catalog.btrim(coalesce(p_note,''));
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin vergibt Coins' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RAISE EXCEPTION 'Der Shop ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_profile_id=me.id THEN RAISE EXCEPTION 'Dem eigenen Konto kannst du keine Coins geben' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_profile_id AND p.is_active AND p.archived_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte ein aktives Profil wählen' USING ERRCODE='22023'; END IF;
 IF p_amount IS NULL OR p_amount=0 OR p_amount NOT BETWEEN -5000 AND 5000 THEN RAISE EXCEPTION 'Betrag zwischen -5000 und 5000 (nicht 0)' USING ERRCODE='22023'; END IF;
 IF pg_catalog.char_length(note) NOT BETWEEN 3 AND 200 THEN RAISE EXCEPTION 'Bitte einen Grund angeben (3–200 Zeichen)' USING ERRCODE='22023'; END IF;
 PERFORM league_private.kg_sync(t.id);
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note,created_by)
 VALUES (t.id,p_amount,'admin',pg_catalog.gen_random_uuid()::text,note,me.id);
 RETURN pg_catalog.jsonb_build_object('profile',t.display_name,'amount',p_amount,'balance',league_private.kg_balance(t.id));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_update_kg_item(p_item_key text, p_price integer, p_min_rank text, p_is_active boolean)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); it public.kg_items;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin ändert den Shop' USING ERRCODE='42501'; END IF;
 SELECT * INTO it FROM public.kg_items x WHERE x.key=p_item_key FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unbekanntes Item' USING ERRCODE='22023'; END IF;
 IF p_is_active IS NULL OR p_min_rank IS NULL OR league_private.kg_rank_of(p_min_rank) IS NULL THEN RAISE EXCEPTION 'Bitte Rang und Status angeben' USING ERRCODE='22023'; END IF;
 IF it.unlock='start' AND (p_min_rank<>'F' OR NOT p_is_active) THEN RAISE EXCEPTION 'Startitems bleiben für alle aktiv' USING ERRCODE='22023'; END IF;
 IF it.unlock='shop' AND (p_price IS NULL OR p_price NOT BETWEEN 10 AND 20000) THEN RAISE EXCEPTION 'Preis zwischen 10 und 20000 Coins' USING ERRCODE='22023'; END IF;
 IF it.unlock<>'shop' AND p_price IS NOT NULL THEN RAISE EXCEPTION 'Dieses Item ist nicht käuflich' USING ERRCODE='22023'; END IF;
 UPDATE public.kg_items x SET price=p_price, min_rank=p_min_rank, is_active=p_is_active, updated_at=now(), updated_by=me.id
 WHERE x.key=it.key RETURNING * INTO it;
 RETURN league_private.kg_item_json(it) || pg_catalog.jsonb_build_object('is_active',it.is_active);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_update_kg_settings(p_start_coins integer, p_coins_per_training integer)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); st public.kg_settings;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin ändert die Coin-Regeln' USING ERRCODE='42501'; END IF;
 IF p_start_coins IS NULL OR p_start_coins NOT BETWEEN 0 AND 5000 THEN RAISE EXCEPTION 'Startguthaben zwischen 0 und 5000' USING ERRCODE='22023'; END IF;
 IF p_coins_per_training IS NULL OR p_coins_per_training NOT BETWEEN 0 AND 500 THEN RAISE EXCEPTION 'Coins pro Training zwischen 0 und 500' USING ERRCODE='22023'; END IF;
 UPDATE public.kg_settings x SET start_coins=p_start_coins, coins_per_training=p_coins_per_training, updated_at=now(), updated_by=me.id
 WHERE x.id=1 RETURNING * INTO st;
 RETURN pg_catalog.jsonb_build_object('start_coins',st.start_coins,'coins_per_training',st.coins_per_training);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_kampfgeist(boolean), public.buy_kg_item(text), public.equip_kg_item(text,text), public.get_kg_look(text),
 public.admin_kg_overview(), public.admin_adjust_coins(uuid,integer,text), public.admin_update_kg_item(text,integer,text,boolean),
 public.admin_update_kg_settings(integer,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_kampfgeist(boolean), public.buy_kg_item(text), public.equip_kg_item(text,text), public.get_kg_look(text),
 public.admin_kg_overview(), public.admin_adjust_coins(uuid,integer,text), public.admin_update_kg_item(text,integer,text,boolean),
 public.admin_update_kg_settings(integer,integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
