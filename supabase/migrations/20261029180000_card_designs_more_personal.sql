-- Etappe 12 (29.10.2026, Owner-Auftrag): mehr FUT-Designs und ein eigenes, selbst gestaltetes Design.
-- * 12 neue Designs: 2 mit dem Rang (Stahl ab E, Kosmos ab A), 10 im Kampfgeist-Shop. Dazu 10 neue Muster.
-- * «Eigenes Design»: Der Admin schaltet es für einzelne Boxer frei. Wer es hat, gestaltet es auf der Website selbst
--   (Name, vier Farben, Muster, optional ein Abzeichen aus 3–5 Buchstaben, Leuchten) und kann es als Karte auswählen.
--   Andere sehen die Karte genau so. Jede Eingabe prüft der Server (nur Farbcodes, nur bekannte Muster).
-- * Entziehen setzt das eigene Design nur auf inaktiv; die Gestaltung bleibt gespeichert. Die Karte fällt dann auf Klassisch zurück.
-- Bestehende Designs, Käufe, Auszeichnungen, Coins und Punkte bleiben unverändert.
BEGIN;

DO $$ BEGIN
 IF to_regclass('public.card_designs') IS NULL OR to_regprocedure('league_private.card_look(uuid)') IS NULL
    OR to_regprocedure('league_private.card_design_available(uuid,public.card_designs)') IS NULL OR to_regprocedure('public.equip_card_design(text)') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Karten-Designs (20261029120000)';
 END IF;
END $$;

-- Freischaltart «personal» (nur für das eigene Design)
DO $$ DECLARE c text; BEGIN
 FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='public.card_designs'::regclass AND contype='c'
   AND pg_get_constraintdef(oid) LIKE '%unlock%' AND pg_get_constraintdef(oid) LIKE '%''award''%' AND pg_get_constraintdef(oid) NOT LIKE '%personal%'
   AND pg_get_constraintdef(oid) LIKE '%ANY%' LOOP
  EXECUTE format('ALTER TABLE public.card_designs DROP CONSTRAINT %I', c);
 END LOOP;
END $$;
ALTER TABLE public.card_designs DROP CONSTRAINT IF EXISTS card_designs_unlock_kind;
ALTER TABLE public.card_designs ADD CONSTRAINT card_designs_unlock_kind CHECK (unlock IN ('start','rank','shop','award','personal'));

INSERT INTO public.card_designs(key,name,description,unlock,min_rank,price,award_kind,design,sort_order) VALUES
 ('stahl','Stahl','Gebürstetes Metall für Rang E.','rank','E',NULL,NULL,'{"a":"#c9d1db","b":"#3b434f","ink":"#10151c","edge":"#ffffff","pattern":"stripes"}',25),
 ('kosmos','Kosmos','Sternenhimmel für Rang A.','rank','A',NULL,NULL,'{"a":"#3b4dff","b":"#070720","ink":"#f5f3ff","edge":"#c9b8ff","pattern":"stars","glow":true}',65),
 ('comic','Comic','Knallgelb mit Rasterpunkten.','shop',NULL,450,NULL,'{"a":"#ffe14d","b":"#e8432e","ink":"#141414","edge":"#141414","pattern":"halftone"}',101),
 ('midnight','Mitternacht','Dunkelblau mit feinen Punkten.','shop',NULL,500,NULL,'{"a":"#2b3a67","b":"#0a0f24","ink":"#e6ecff","edge":"#8fa6ff","pattern":"dots"}',102),
 ('retro','Retro','Pink und Lila wie in den Achtzigern.','shop',NULL,550,NULL,'{"a":"#ff7ab6","b":"#3b1c6e","ink":"#fff6d6","edge":"#ffd166","pattern":"stripes"}',103),
 ('marmor','Marmor','Heller Marmor mit Goldrand.','shop',NULL,650,NULL,'{"a":"#f4f1ea","b":"#a9a49a","ink":"#1d1a16","edge":"#c6a15b","pattern":"marble"}',104),
 ('dschungel','Dschungel','Tarnmuster in Grün.','shop',NULL,700,NULL,'{"a":"#8fbf5a","b":"#24361a","ink":"#f3ffe6","edge":"#d9f99d","pattern":"camo"}',105),
 ('eiskristall','Eiskristall','Kaltes Weiss-Blau mit Waben.','shop',NULL,800,NULL,'{"a":"#e6fbff","b":"#4aa3c7","ink":"#06212e","edge":"#ffffff","pattern":"hex"}',106),
 ('cyber','Cyber','Leuchtende Leiterbahnen.','shop',NULL,1000,NULL,'{"a":"#00f0b5","b":"#061a1f","ink":"#e6fff9","edge":"#00f0b5","pattern":"circuit","glow":true}',107),
 ('tiger','Tiger','Orange mit schwarzen Streifen.','shop',NULL,1100,NULL,'{"a":"#ffb02e","b":"#3a1d00","ink":"#fff3df","edge":"#111111","pattern":"tiger"}',108),
 ('goldrausch','Goldrausch','Gold mit funkelnden Sternen.','shop',NULL,1200,NULL,'{"a":"#ffe08a","b":"#7a4d00","ink":"#2b1b00","edge":"#fff3c4","pattern":"stars","glow":true}',109),
 ('inferno','Inferno','Flammen von unten.','shop',NULL,1500,NULL,'{"a":"#ffcf3f","b":"#7a0d00","ink":"#fff1e0","edge":"#ff7a1a","pattern":"flames","glow":true}',110),
 ('eigen','Eigenes Design','Selbst gestaltet – nur für dich freigeschaltet.','personal',NULL,NULL,NULL,'{"a":"#f2c14e","b":"#0b1327","ink":"#ffffff","edge":"#f2c14e","pattern":"rays"}',140)
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.card_personal_designs(
 profile_id uuid PRIMARY KEY REFERENCES public.profiles(id),
 name text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 24),
 design jsonb NOT NULL CHECK (jsonb_typeof(design)='object'),
 is_active boolean NOT NULL DEFAULT true,
 granted_by uuid NOT NULL REFERENCES public.profiles(id),
 granted_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.card_personal_designs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.card_personal_designs FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen
CREATE OR REPLACE FUNCTION league_private.card_patterns()
RETURNS text[] LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT ARRAY['carbon','waves','sparks','aurora','crown','rays','grid','petals','bolts','diamond',
  'stripes','stars','halftone','dots','marble','camo','hex','circuit','tiger','flames']
$fn$;

-- Eigenes Design prüfen: nur bekannte Felder, Farben als #rrggbb, bekanntes Muster, Abzeichen 3–5 Grossbuchstaben, Leuchten ja/nein.
CREATE OR REPLACE FUNCTION league_private.card_personal_clean(p jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE k text; o jsonb := '{}'::jsonb;
BEGIN
 IF p IS NULL OR pg_catalog.jsonb_typeof(p)<>'object' THEN RAISE EXCEPTION 'Ungültiges Design' USING ERRCODE='22023'; END IF;
 FOR k IN SELECT pg_catalog.jsonb_object_keys(p) LOOP
  IF k NOT IN ('a','b','ink','edge','pattern','badge','glow') THEN RAISE EXCEPTION 'Unbekanntes Feld: %', pg_catalog.left(k,20) USING ERRCODE='22023'; END IF;
 END LOOP;
 FOREACH k IN ARRAY ARRAY['a','b','ink','edge'] LOOP
  IF coalesce(pg_catalog.jsonb_typeof(p->k),'')<>'string' OR coalesce(p->>k,'') !~ '^#[0-9a-fA-F]{6}$' THEN RAISE EXCEPTION 'Bitte für alle vier Farben einen Farbcode wählen' USING ERRCODE='22023'; END IF;
  o := o || pg_catalog.jsonb_build_object(k, pg_catalog.lower(p->>k));
 END LOOP;
 IF coalesce(pg_catalog.jsonb_typeof(p->'pattern'),'')<>'string' OR NOT coalesce(p->>'pattern' = ANY(league_private.card_patterns()),false) THEN RAISE EXCEPTION 'Bitte ein Muster aus der Liste wählen' USING ERRCODE='22023'; END IF;
 o := o || pg_catalog.jsonb_build_object('pattern', p->>'pattern');
 IF p ? 'badge' AND p->'badge'<>'null'::jsonb AND coalesce(p->>'badge','')<>'' THEN
  IF coalesce(pg_catalog.jsonb_typeof(p->'badge'),'')<>'string' OR coalesce(p->>'badge','') !~ '^[A-Z]{3,5}$' THEN RAISE EXCEPTION 'Abzeichen: 3 bis 5 Grossbuchstaben (A–Z)' USING ERRCODE='22023'; END IF;
  o := o || pg_catalog.jsonb_build_object('badge', p->>'badge');
 END IF;
 IF p ? 'glow' AND p->'glow'<>'null'::jsonb THEN
  IF coalesce(pg_catalog.jsonb_typeof(p->'glow'),'')<>'boolean' THEN RAISE EXCEPTION 'Leuchten: ja oder nein' USING ERRCODE='22023'; END IF;
  IF (p->>'glow')::boolean THEN o := o || '{"glow":true}'::jsonb; END IF;
 END IF;
 RETURN o;
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.card_personal_name(p text)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE n text := pg_catalog.btrim(coalesce(p,''));
BEGIN
 IF pg_catalog.char_length(n) NOT BETWEEN 2 AND 24 OR n ~ '[<>\x00-\x1f]' THEN RAISE EXCEPTION 'Name: 2 bis 24 Zeichen, ohne < und >' USING ERRCODE='22023'; END IF;
 RETURN n;
END;
$fn$;

-- Verfügbar wie bisher, dazu: eigenes Design nur mit aktiver Freischaltung.
CREATE OR REPLACE FUNCTION league_private.card_design_available(p uuid, d public.card_designs)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT d.is_active AND CASE d.unlock
  WHEN 'start' THEN true
  WHEN 'rank' THEN league_private.card_rank_idx(p) >= pg_catalog.array_position(ARRAY['F','E','D','C','B','A','S'],d.min_rank)-1
  WHEN 'shop' THEN EXISTS (SELECT 1 FROM public.card_design_purchases x WHERE x.profile_id=p AND x.design_key=d.key)
  WHEN 'award' THEN EXISTS (SELECT 1 FROM public.card_awards a WHERE a.profile_id=p AND a.kind=d.award_kind AND a.revoked_at IS NULL)
  WHEN 'personal' THEN EXISTS (SELECT 1 FROM public.card_personal_designs x WHERE x.profile_id=p AND x.is_active)
  ELSE false END
$fn$;

-- Angezeigtes Design: wie bisher; beim eigenen Design Name und Gestaltung des Boxers.
CREATE OR REPLACE FUNCTION league_private.card_look(p uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE d public.card_designs; pd public.card_personal_designs;
BEGIN
 SELECT x.* INTO d FROM public.card_design_equipped e JOIN public.card_designs x ON x.key=e.design_key WHERE e.profile_id=p;
 IF d.key IS NULL OR NOT league_private.card_design_available(p,d) THEN SELECT * INTO d FROM public.card_designs WHERE key='classic'; END IF;
 IF d.unlock='personal' THEN
  SELECT * INTO pd FROM public.card_personal_designs x WHERE x.profile_id=p AND x.is_active;
  d.name := pd.name; d.design := pd.design;
 END IF;
 RETURN pg_catalog.jsonb_build_object('key',d.key,'name',d.name,'design',d.design,
  'awards',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('kind',a.kind,'period_start',a.period_start) ORDER BY a.period_start DESC)
    FROM public.card_awards a WHERE a.profile_id=p AND a.revoked_at IS NULL),'[]'::jsonb));
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.card_patterns(), league_private.card_personal_clean(jsonb), league_private.card_personal_name(text),
 league_private.card_design_available(uuid,public.card_designs), league_private.card_look(uuid) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Boxer: eigenes Design lesen und speichern
CREATE OR REPLACE FUNCTION public.get_my_personal_design()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); pd public.card_personal_designs;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('card_designs') AND me.role NOT IN ('admin','coach') THEN RETURN pg_catalog.jsonb_build_object('granted',false); END IF;
 SELECT * INTO pd FROM public.card_personal_designs x WHERE x.profile_id=me.id AND x.is_active;
 IF pd.profile_id IS NULL THEN RETURN pg_catalog.jsonb_build_object('granted',false); END IF;
 RETURN pg_catalog.jsonb_build_object('granted',true,'name',pd.name,'design',pd.design,'updated_at',pd.updated_at,
  'patterns',pg_catalog.to_jsonb(league_private.card_patterns()),
  'equipped',EXISTS (SELECT 1 FROM public.card_design_equipped e WHERE e.profile_id=me.id AND e.design_key='eigen'));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.save_my_personal_design(p_name text, p_design jsonb)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); n text; d jsonb;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('card_designs') AND me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Karten-Designs sind noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.card_personal_designs x WHERE x.profile_id=me.id AND x.is_active) THEN
  RAISE EXCEPTION 'Ein eigenes Design schaltet der Admin frei' USING ERRCODE='42501';
 END IF;
 IF p_design IS NULL OR pg_catalog.octet_length(p_design::text)>1000 THEN RAISE EXCEPTION 'Ungültiges Design' USING ERRCODE='22023'; END IF;
 n := league_private.card_personal_name(p_name);
 d := league_private.card_personal_clean(p_design);
 UPDATE public.card_personal_designs SET name=n, design=d, updated_at=now() WHERE profile_id=me.id;
 RETURN pg_catalog.jsonb_build_object('name',n,'design',d,'look',league_private.card_look(me.id));
END;
$fn$;

-- Admin: eigenes Design freischalten oder entziehen (Gestaltung bleibt gespeichert)
CREATE OR REPLACE FUNCTION public.admin_list_personal_designs()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('profile_id',p.id,'display_name',p.display_name,
   'active',coalesce(x.is_active,false),'name',x.name) ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p LEFT JOIN public.card_personal_designs x ON x.profile_id=p.id
  WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_set_personal_design(p_profile_id uuid, p_active boolean)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); t public.profiles; base jsonb;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 IF p_active IS NULL THEN RAISE EXCEPTION 'Bitte freischalten oder entziehen' USING ERRCODE='22023'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_profile_id AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023'; END IF;
 SELECT d.design INTO base FROM public.card_designs d WHERE d.key='eigen';
 IF p_active THEN
  INSERT INTO public.card_personal_designs(profile_id,name,design,is_active,granted_by)
  VALUES (t.id,'Eigenes Design',base,true,me.id)
  ON CONFLICT (profile_id) DO UPDATE SET is_active=true, granted_by=me.id, granted_at=now();
  INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
  VALUES (t.id,'general','Dein eigenes Karten-Design ist freigeschaltet','Gestalte Farben, Muster und Abzeichen deiner Spielerkarte selbst.','/karten.html');
 ELSE
  UPDATE public.card_personal_designs SET is_active=false WHERE profile_id=t.id;
 END IF;
 RETURN pg_catalog.jsonb_build_object('profile_id',t.id,'display_name',t.display_name,'active',p_active);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_personal_design(), public.save_my_personal_design(text,jsonb),
 public.admin_list_personal_designs(), public.admin_set_personal_design(uuid,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_personal_design(), public.save_my_personal_design(text,jsonb),
 public.admin_list_personal_designs(), public.admin_set_personal_design(uuid,boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
