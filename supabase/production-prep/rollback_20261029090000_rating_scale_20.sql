-- Rollback für 20261029090000_rating_scale_20.sql (Etappe 7a): vorherige Bewertungsfunktionen (Skala 1–10) wiederherstellen.
-- Bricht ab, wenn schon Bewertungen auf der 20er-Skala gespeichert sind (die alten Funktionen würden sie falsch rechnen).
-- Die Spalte scale bleibt (Vorgabe 10); es werden keine Bewertungen gelöscht oder geändert.
BEGIN;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.boxer_ratings WHERE scale<>10) THEN
  RAISE EXCEPTION 'Rollback abgebrochen: Es gibt Bewertungen auf der 20er-Skala. Erst mit dem Owner klären.';
 END IF;
END $$;
DROP FUNCTION IF EXISTS public.staff_rate_boxer(uuid,jsonb,text,integer);
-- Vorherige Versionen (aus 20261028180000_coach_ratings_style_test.sql)
CREATE OR REPLACE FUNCTION league_private.rating_full(p_boxer uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE cur public.boxer_ratings; prev public.boxer_ratings;
BEGIN
 cur := league_private.rating_row(p_boxer,0);
 IF cur.id IS NULL THEN RETURN NULL; END IF;
 prev := league_private.rating_row(p_boxer,1);
 RETURN pg_catalog.jsonb_build_object(
  'current',pg_catalog.jsonb_build_object('scores',cur.scores,'summary',league_private.rating_summary(cur.scores),
     'created_at',cur.created_at,'note',cur.note,
     'rated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=cur.rated_by)),
  'previous',CASE WHEN prev.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('scores',prev.scores,
     'summary',league_private.rating_summary(prev.scores),'created_at',prev.created_at) END);
END;
$fn$;

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
   sm := league_private.rating_summary(cur.scores);
   sm := sm || pg_catalog.jsonb_build_object('rated_at',cur.created_at,
     'delta',CASE WHEN prev.id IS NULL THEN NULL ELSE (sm->>'overall')::integer-(league_private.rating_summary(prev.scores)->>'overall')::integer END);
  END IF;
 END IF;
 RETURN pg_catalog.jsonb_build_object('display_name',t.display_name,
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
   'overall',(SELECT (league_private.rating_summary(r.scores)->>'overall')::integer FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'rated_at',(SELECT r.created_at FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'style',league_private.style_state(p.id),
   'style_scores',(SELECT t.scores FROM public.style_tests t WHERE t.boxer_id=p.id ORDER BY t.created_at DESC, t.id DESC LIMIT 1),
   'is_self',p.id=me.id) ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_rate_boxer(p_boxer_id uuid, p_scores jsonb, p_note text DEFAULT NULL)
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
 IF NOT league_private.rating_scores_valid(p_scores) THEN
  RAISE EXCEPTION 'Bitte alle 25 Noten von 1 bis 10 vergeben' USING ERRCODE='22023';
 END IF;
 note := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF note IS NOT NULL AND pg_catalog.char_length(note)>600 THEN RAISE EXCEPTION 'Der Kommentar darf höchstens 600 Zeichen haben' USING ERRCODE='22023'; END IF;
 last := league_private.rating_row(t.id,0);
 -- Doppelklick: identische Bewertung desselben Trainers innerhalb von 2 Minuten wird nicht doppelt gespeichert.
 IF last.id IS NOT NULL AND last.rated_by=me.id AND last.scores=p_scores AND last.note IS NOT DISTINCT FROM note
    AND last.created_at > now() - interval '2 minutes' THEN
  RETURN pg_catalog.jsonb_build_object('id',last.id,'duplicate',true,'overall',(league_private.rating_summary(last.scores)->>'overall')::integer);
 END IF;
 before := CASE WHEN last.id IS NULL THEN NULL ELSE (league_private.rating_summary(last.scores)->>'overall')::integer END;
 INSERT INTO public.boxer_ratings(boxer_id,rated_by,scores,note) VALUES (t.id,me.id,p_scores,note) RETURNING id INTO new_id;
 RETURN pg_catalog.jsonb_build_object('id',new_id,'boxer',t.display_name,'previous_overall',before,
  'overall',(league_private.rating_summary(p_scores)->>'overall')::integer);
END;
$fn$;

DROP FUNCTION IF EXISTS league_private.rating_summary(jsonb,integer);
DROP FUNCTION IF EXISTS league_private.rating_scores_valid(jsonb,integer);
REVOKE ALL ON FUNCTION league_private.rating_full(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_performance_card(text), public.staff_list_performance(), public.staff_rate_boxer(uuid,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_performance_card(text), public.staff_list_performance(), public.staff_rate_boxer(uuid,jsonb,text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
