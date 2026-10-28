-- Etappe 7a (28.10.2026, Owner-Auftrag): Coach-Bewertung mit Regler von 1 bis 20.
-- * Neue Bewertungen speichern 25 Noten von 1 bis 20 (scale = 20). Bisherige Bewertungen (1 bis 10) bleiben unverändert
--   gespeichert und werden mit scale = 10 weiter richtig gerechnet: Bereich = Durchschnitt / scale × 100 (max. 99).
--   Damit bleibt die Gesamtwertung bestehender Karten exakt gleich; keine Daten werden umgeschrieben.
-- * staff_rate_boxer hat den neuen Parameter p_scale (Vorgabe 10). Die bisherige Oberfläche schickt keinen Wert und speichert
--   weiter richtig auf der 10er-Skala; die neue Oberfläche schickt p_scale = 20.
-- * Ausgaben enthalten zusätzlich «scale», damit die Oberfläche Einzelnoten auf 1–20 darstellen kann.
BEGIN;

DO $$ BEGIN
 IF to_regclass('public.boxer_ratings') IS NULL OR to_regprocedure('league_private.rating_summary(jsonb)') IS NULL
    OR to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text)') IS NULL AND to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text,integer)') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: 20261028180000_coach_ratings_style_test';
 END IF;
END $$;

ALTER TABLE public.boxer_ratings ADD COLUMN IF NOT EXISTS scale smallint NOT NULL DEFAULT 10;
ALTER TABLE public.boxer_ratings DROP CONSTRAINT IF EXISTS boxer_ratings_scale_check;
ALTER TABLE public.boxer_ratings ADD CONSTRAINT boxer_ratings_scale_check CHECK (scale IN (10,20));

-- Noten gültig: alle 25 Kriterien, ganze Zahlen von 1 bis p_scale.
CREATE OR REPLACE FUNCTION league_private.rating_scores_valid(p jsonb, p_scale integer)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE k text; expected text[]; v jsonb; n numeric;
BEGIN
 IF p_scale NOT IN (10,20) OR p IS NULL OR pg_catalog.jsonb_typeof(p)<>'object' THEN RETURN false; END IF;
 SELECT pg_catalog.array_agg(x ORDER BY x) INTO expected FROM league_private.rating_categories() c, LATERAL pg_catalog.unnest(c.keys) x;
 IF (SELECT pg_catalog.array_agg(x ORDER BY x) FROM pg_catalog.jsonb_object_keys(p) x) IS DISTINCT FROM expected THEN RETURN false; END IF;
 FOREACH k IN ARRAY expected LOOP
  v := p->k;
  IF pg_catalog.jsonb_typeof(v)<>'number' THEN RETURN false; END IF;
  n := (v#>>'{}')::numeric;
  IF n<>pg_catalog.trunc(n) OR n<1 OR n>p_scale THEN RETURN false; END IF;
 END LOOP;
 RETURN true;
END;
$fn$;

-- Karte: Bereich = Durchschnitt / scale × 100 (max. 99), Gesamt = gewichteter Schnitt (max. 99).
-- Stärken/Schwächen: Rohwert «v» plus «scale» (bei scale 10 identisch mit bisher).
CREATE OR REPLACE FUNCTION league_private.rating_summary(p jsonb, p_scale integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 WITH c AS (
  SELECT c.cat, c.weight, LEAST(99, round(pg_catalog.avg((p->>k)::numeric)*100/p_scale))::integer AS v
  FROM league_private.rating_categories() c, LATERAL pg_catalog.unnest(c.keys) k GROUP BY c.cat, c.weight
 ), s AS (
  SELECT k, (p->>k)::integer AS v, c.co*100+k.ko AS ord
  FROM league_private.rating_categories() WITH ORDINALITY c(cat,weight,keys,co), LATERAL pg_catalog.unnest(c.keys) WITH ORDINALITY k(k,ko)
 )
 SELECT pg_catalog.jsonb_build_object(
  'scale',p_scale,
  'categories',(SELECT pg_catalog.jsonb_object_agg(cat,v) FROM c),
  'overall',(SELECT LEAST(99, round(pg_catalog.sum(v*weight)/100.0))::integer FROM c),
  'top',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('k',k,'v',v) ORDER BY v DESC, ord) FROM (SELECT * FROM s ORDER BY v DESC, ord LIMIT 3) t),
  'low',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('k',k,'v',v) ORDER BY v, ord) FROM (SELECT * FROM s ORDER BY v, ord LIMIT 3) t))
$fn$;

CREATE OR REPLACE FUNCTION league_private.rating_full(p_boxer uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE cur public.boxer_ratings; prev public.boxer_ratings;
BEGIN
 cur := league_private.rating_row(p_boxer,0);
 IF cur.id IS NULL THEN RETURN NULL; END IF;
 prev := league_private.rating_row(p_boxer,1);
 RETURN pg_catalog.jsonb_build_object(
  'current',pg_catalog.jsonb_build_object('scores',cur.scores,'scale',cur.scale,'summary',league_private.rating_summary(cur.scores,cur.scale),
     'created_at',cur.created_at,'note',cur.note,
     'rated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=cur.rated_by)),
  'previous',CASE WHEN prev.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('scores',prev.scores,'scale',prev.scale,
     'summary',league_private.rating_summary(prev.scores,prev.scale),'created_at',prev.created_at) END);
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.rating_scores_valid(jsonb,integer), league_private.rating_summary(jsonb,integer),
 league_private.rating_full(uuid) FROM PUBLIC, anon, authenticated;

-- Karte eines anderen Boxers (unverändert bis auf die Skala).
CREATE OR REPLACE FUNCTION public.get_performance_card(p_display_name text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; t public.profiles; n integer; staff boolean; r_on boolean; s_on boolean;
 cur public.boxer_ratings; prev public.boxer_ratings; sm jsonb;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL THEN RETURN NULL; END IF;
 SELECT count(*) INTO n FROM public.profiles p
 WHERE pg_catalog.lower(p.display_name)=pg_catalog.lower(pg_catalog.btrim(coalesce(p_display_name,'')))
   AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 IF n<>1 THEN RETURN NULL; END IF;
 SELECT * INTO t FROM public.profiles p
 WHERE pg_catalog.lower(p.display_name)=pg_catalog.lower(pg_catalog.btrim(p_display_name))
   AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 staff := me.role IN ('admin','coach');
 IF t.id<>me.id AND NOT staff AND t.is_listed IS NOT TRUE THEN RETURN NULL; END IF;
 r_on := league_private.flag_on('coach_ratings') OR staff;
 s_on := league_private.flag_on('style_test') OR staff;
 IF r_on THEN
  cur := league_private.rating_row(t.id,0); prev := league_private.rating_row(t.id,1);
  IF cur.id IS NOT NULL THEN
   sm := league_private.rating_summary(cur.scores,cur.scale);
   sm := sm || pg_catalog.jsonb_build_object('rated_at',cur.created_at,
     'delta',CASE WHEN prev.id IS NULL THEN NULL ELSE (sm->>'overall')::integer-(league_private.rating_summary(prev.scores,prev.scale)->>'overall')::integer END);
  END IF;
 END IF;
 RETURN pg_catalog.jsonb_build_object('display_name',t.display_name,'is_me',t.id=me.id,
  'rating',sm,
  'style',CASE WHEN s_on THEN (SELECT pg_catalog.jsonb_build_object('scores',x.scores,'created_at',x.created_at) FROM public.style_tests x
            WHERE x.boxer_id=t.id ORDER BY x.created_at DESC, x.id DESC LIMIT 1) END);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_list_performance()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für Trainer und Admins' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'id',p.id,'display_name',p.display_name,'role',p.role,
   'overall',(SELECT (league_private.rating_summary(r.scores,r.scale)->>'overall')::integer FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'rated_at',(SELECT r.created_at FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'style',league_private.style_state(p.id),
   'style_scores',(SELECT t.scores FROM public.style_tests t WHERE t.boxer_id=p.id ORDER BY t.created_at DESC, t.id DESC LIMIT 1),
   'is_self',p.id=me.id) ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

-- Bewerten: p_scale 10 (bisherige Oberfläche) oder 20 (Regler).
DROP FUNCTION IF EXISTS public.staff_rate_boxer(uuid,jsonb,text);
CREATE OR REPLACE FUNCTION public.staff_rate_boxer(p_boxer_id uuid, p_scores jsonb, p_note text DEFAULT NULL, p_scale integer DEFAULT 10)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; t public.profiles; last public.boxer_ratings; note text; new_id bigint; before integer;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur aktive Trainer und Admins dürfen bewerten' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_boxer_id FOR UPDATE;
 IF NOT FOUND OR t.role NOT IN ('boxer','coach') OR NOT t.is_active OR t.archived_at IS NOT NULL THEN
  RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023';
 END IF;
 IF t.id=me.id THEN RAISE EXCEPTION 'Die eigene Bewertung macht ein anderer Trainer' USING ERRCODE='42501'; END IF;
 IF coalesce(p_scale,0) NOT IN (10,20) THEN RAISE EXCEPTION 'Unbekannte Skala' USING ERRCODE='22023'; END IF;
 IF NOT league_private.rating_scores_valid(p_scores,p_scale) THEN
  RAISE EXCEPTION 'Bitte alle 25 Noten von 1 bis % vergeben', p_scale USING ERRCODE='22023';
 END IF;
 note := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF note IS NOT NULL AND pg_catalog.char_length(note)>600 THEN RAISE EXCEPTION 'Der Kommentar darf höchstens 600 Zeichen haben' USING ERRCODE='22023'; END IF;
 last := league_private.rating_row(t.id,0);
 -- Doppelklick: identische Bewertung desselben Trainers innerhalb von 2 Minuten wird nicht doppelt gespeichert.
 IF last.id IS NOT NULL AND last.rated_by=me.id AND last.scores=p_scores AND last.scale=p_scale AND last.note IS NOT DISTINCT FROM note
    AND last.created_at > now() - interval '2 minutes' THEN
  RETURN pg_catalog.jsonb_build_object('id',last.id,'duplicate',true,'overall',(league_private.rating_summary(last.scores,last.scale)->>'overall')::integer);
 END IF;
 before := CASE WHEN last.id IS NULL THEN NULL ELSE (league_private.rating_summary(last.scores,last.scale)->>'overall')::integer END;
 INSERT INTO public.boxer_ratings(boxer_id,rated_by,scores,note,scale) VALUES (t.id,me.id,p_scores,note,p_scale) RETURNING id INTO new_id;
 RETURN pg_catalog.jsonb_build_object('id',new_id,'boxer',t.display_name,'previous_overall',before,'scale',p_scale,
  'overall',(league_private.rating_summary(p_scores,p_scale)->>'overall')::integer);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_performance_card(text), public.staff_list_performance(),
 public.staff_rate_boxer(uuid,jsonb,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_performance_card(text), public.staff_list_performance(),
 public.staff_rate_boxer(uuid,jsonb,text,integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
