-- Etappe 15 (29.10.2026, Owner-Auftrag): Öffentliche Kartenwerte richten sich nach der besten Karte (= 92).
-- * Die beste aktuelle Gesamtwertung aller aktiven Boxer und Trainer (echte Coach-Bewertung, letzte pro Person) wird öffentlich
--   als 92 gezeigt. Alle anderen Werte (Gesamt und die sechs Kategorien) werden im gleichen Verhältnis umgerechnet: Wert × 92 / beste,
--   gerundet, höchstens 99. Wird jemand besser als die bisher beste Karte, verschiebt sich die Skala für alle.
-- * Öffentlich (Profil, Vergleich, Podium, Trainer-Übersicht über get_performance_card): nur die umgerechneten Werte.
-- * Eigene Bewertung und Trainer-Bewertung (rating_full): die echten Werte wie bisher, dazu 'public' mit den umgerechneten Werten.
-- * Trainer-Liste (staff_list_performance): echte Gesamtwertung wie bisher, dazu public_overall.
-- * get_rating_card_scale(): beste Gesamtwertung (mit und ohne einen Boxer) für die Live-Vorschau im Bewertungsformular.
-- Gespeicherte Noten, Selbsteinschätzungen, Punkte und EXP bleiben unverändert; es wird nur anders angezeigt.

BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.rating_summary(jsonb,integer)') IS NULL OR to_regprocedure('league_private.rating_row(uuid,integer)') IS NULL
    OR to_regprocedure('public.get_performance_card(text)') IS NULL OR to_regprocedure('league_private.rating_full(uuid)') IS NULL
    OR to_regprocedure('public.staff_list_performance()') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Coach-Bewertung mit 20er-Skala (20261029090000)';
 END IF;
END $$;

-- Beste echte Gesamtwertung (letzte Coach-Bewertung je aktivem Boxer/Trainer), optional ohne einen bestimmten Boxer.
CREATE OR REPLACE FUNCTION league_private.rating_card_best(p_exclude uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT max((league_private.rating_summary(r.scores,r.scale)->>'overall')::integer)
 FROM public.profiles p CROSS JOIN LATERAL league_private.rating_row(p.id,0) r
 WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach') AND r.id IS NOT NULL
   AND (p_exclude IS NULL OR p.id<>p_exclude)
$fn$;

-- Öffentliche Werte: Gesamt und Kategorien × 92 / beste, gerundet, höchstens 99 (ohne beste Karte: unverändert).
CREATE OR REPLACE FUNCTION league_private.rating_public(sm jsonb, best integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT CASE WHEN sm IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('target',92,'best',best,
  'overall',CASE WHEN coalesce(best,0)<=0 THEN (sm->>'overall')::integer ELSE LEAST(99, round((sm->>'overall')::numeric*92/best))::integer END,
  'categories',(SELECT pg_catalog.jsonb_object_agg(c.key, CASE WHEN coalesce(best,0)<=0 THEN c.value::integer ELSE LEAST(99, round(c.value::numeric*92/best))::integer END)
    FROM pg_catalog.jsonb_each_text(sm->'categories') c)) END
$fn$;

REVOKE ALL ON FUNCTION league_private.rating_card_best(uuid), league_private.rating_public(jsonb,integer) FROM PUBLIC, anon, authenticated;

-- Öffentliche Karte: umgerechnete Werte (Rest wie 20261029090000).
CREATE OR REPLACE FUNCTION public.get_performance_card(p_display_name text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; t public.profiles; n integer; staff boolean; r_on boolean; s_on boolean;
 cur public.boxer_ratings; prev public.boxer_ratings; sm jsonb; best integer; pub jsonb;
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
   best := league_private.rating_card_best(NULL);
   pub := league_private.rating_public(league_private.rating_summary(cur.scores,cur.scale),best);
   sm := league_private.rating_summary(cur.scores,cur.scale) || pg_catalog.jsonb_build_object('overall',pub->'overall','categories',pub->'categories',
     'scaled',true,'target',pub->'target','rated_at',cur.created_at,
     'delta',CASE WHEN prev.id IS NULL THEN NULL ELSE (pub->>'overall')::integer
       -(league_private.rating_public(league_private.rating_summary(prev.scores,prev.scale),best)->>'overall')::integer END);
  END IF;
 END IF;
 RETURN pg_catalog.jsonb_build_object('display_name',t.display_name,'is_me',t.id=me.id,
  'rating',sm,
  'style',CASE WHEN s_on THEN (SELECT pg_catalog.jsonb_build_object('scores',x.scores,'created_at',x.created_at) FROM public.style_tests x
            WHERE x.boxer_id=t.id ORDER BY x.created_at DESC, x.id DESC LIMIT 1) END);
END;
$fn$;

-- Eigene / Trainer-Sicht: echte Werte wie bisher, dazu 'public'.
CREATE OR REPLACE FUNCTION league_private.rating_full(p_boxer uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE cur public.boxer_ratings; prev public.boxer_ratings; best integer := league_private.rating_card_best(NULL);
BEGIN
 cur := league_private.rating_row(p_boxer,0);
 IF cur.id IS NULL THEN RETURN NULL; END IF;
 prev := league_private.rating_row(p_boxer,1);
 RETURN pg_catalog.jsonb_build_object(
  'current',pg_catalog.jsonb_build_object('scores',cur.scores,'scale',cur.scale,'summary',league_private.rating_summary(cur.scores,cur.scale)
       || pg_catalog.jsonb_build_object('public',league_private.rating_public(league_private.rating_summary(cur.scores,cur.scale),best)),
     'created_at',cur.created_at,'note',cur.note,
     'rated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=cur.rated_by)),
  'previous',CASE WHEN prev.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('scores',prev.scores,'scale',prev.scale,
     'summary',league_private.rating_summary(prev.scores,prev.scale)
       || pg_catalog.jsonb_build_object('public',league_private.rating_public(league_private.rating_summary(prev.scores,prev.scale),best)),'created_at',prev.created_at) END);
END;
$fn$;

-- Trainer-Liste: wie 20261029090000, dazu public_overall.
CREATE OR REPLACE FUNCTION public.staff_list_performance()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; best integer := league_private.rating_card_best(NULL);
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für Trainer und Admins' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'id',p.id,'display_name',p.display_name,'role',p.role,
   'overall',(SELECT (league_private.rating_summary(r.scores,r.scale)->>'overall')::integer FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'public_overall',(SELECT (league_private.rating_public(league_private.rating_summary(r.scores,r.scale),best)->>'overall')::integer
     FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'rated_at',(SELECT r.created_at FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'style',league_private.style_state(p.id),
   'style_scores',(SELECT t.scores FROM public.style_tests t WHERE t.boxer_id=p.id ORDER BY t.created_at DESC, t.id DESC LIMIT 1),
   'is_self',p.id=me.id) ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

-- Für die Live-Vorschau: beste Gesamtwertung, und beste ohne den bewerteten Boxer (Boxer nur für sich selbst).
CREATE OR REPLACE FUNCTION public.get_rating_card_scale(p_boxer_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); who uuid;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 who := coalesce(p_boxer_id, me.id);
 IF who<>me.id AND me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für Trainer und Admins' USING ERRCODE='42501'; END IF;
 RETURN pg_catalog.jsonb_build_object('target',92,'best',league_private.rating_card_best(NULL),'best_others',league_private.rating_card_best(who));
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_performance_card(text), public.staff_list_performance(), public.get_rating_card_scale(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_performance_card(text), public.staff_list_performance(), public.get_rating_card_scale(uuid) TO authenticated;
REVOKE ALL ON FUNCTION league_private.rating_full(uuid) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
