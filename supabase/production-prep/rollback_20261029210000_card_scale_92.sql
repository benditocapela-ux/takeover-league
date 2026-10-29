-- Rücknahme von 20261029210000_card_scale_92.sql: Karten wieder mit echten Werten überall (Stand 20261029090000).
-- Stellt get_performance_card, rating_full und staff_list_performance wörtlich wieder her und entfernt die neuen Funktionen. Ändert keine Daten.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('league_private.rating_public(jsonb,integer)') IS NULL THEN RAISE EXCEPTION 'Etappe 15 ist nicht eingespielt'; END IF;
END $$;

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

DROP FUNCTION public.get_rating_card_scale(uuid);
DROP FUNCTION league_private.rating_public(jsonb,integer);
DROP FUNCTION league_private.rating_card_best(uuid);
NOTIFY pgrst, 'reload schema';
COMMIT;
