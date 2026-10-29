-- Etappe 16 (29.10.2026, Owner-Auftrag): Kartenarena im Boxervergleich.
-- * public.get_card_gallery(): alle Spielerkarten auf einmal, von der besten zur schlechtesten (öffentliche Werte wie
--   get_performance_card, Etappe 15: beste Karte = 92). Dazu Pfeil, Datum und der letzte Boxstil.
-- * Sichtbarkeit genau wie get_performance_card: nur angemeldete Mitglieder; sichtbare Profile (is_listed), das eigene,
--   Trainer und Admins sehen alle; nur eindeutige Namen; Karten nur mit Coach-Bewertung (Flag), Boxstil nur mit Flag.
-- * Keine Einzelnoten, keine Kommentare. Keine Daten werden geändert.

BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.rating_public(jsonb,integer)') IS NULL OR to_regprocedure('league_private.rating_card_best(uuid)') IS NULL
    OR to_regprocedure('public.get_performance_card(text)') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: öffentliche Kartenwerte (20261029210000)';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.get_card_gallery()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); staff boolean; r_on boolean; s_on boolean; best integer;
BEGIN
 IF me.id IS NULL THEN RETURN '[]'::jsonb; END IF;
 staff := me.role IN ('admin','coach');
 r_on := league_private.flag_on('coach_ratings') OR staff;
 s_on := league_private.flag_on('style_test') OR staff;
 best := league_private.rating_card_best(NULL);
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(x.obj ORDER BY x.ov DESC NULLS LAST, pg_catalog.lower(x.name))
  FROM (SELECT p.display_name AS name,
     CASE WHEN r_on AND cur.id IS NOT NULL THEN (pub->>'overall')::integer END AS ov,
     pg_catalog.jsonb_build_object('display_name',p.display_name,'is_me',p.id=me.id,
      'rating',CASE WHEN r_on AND cur.id IS NOT NULL THEN pg_catalog.jsonb_build_object('overall',pub->'overall','categories',pub->'categories',
        'scaled',true,'target',pub->'target','rated_at',cur.created_at,
        'delta',CASE WHEN prev.id IS NULL THEN NULL ELSE (pub->>'overall')::integer
          -(league_private.rating_public(league_private.rating_summary(prev.scores,prev.scale),best)->>'overall')::integer END) END,
      'style',CASE WHEN s_on THEN (SELECT pg_catalog.jsonb_build_object('scores',t.scores,'created_at',t.created_at) FROM public.style_tests t
        WHERE t.boxer_id=p.id ORDER BY t.created_at DESC, t.id DESC LIMIT 1) END) AS obj
   FROM public.profiles p
   CROSS JOIN LATERAL league_private.rating_row(p.id,0) cur
   CROSS JOIN LATERAL league_private.rating_row(p.id,1) prev
   CROSS JOIN LATERAL (SELECT CASE WHEN cur.id IS NULL THEN NULL ELSE league_private.rating_public(league_private.rating_summary(cur.scores,cur.scale),best) END AS pub) z
   WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')
     AND (p.id=me.id OR staff OR p.is_listed IS TRUE)
     AND (SELECT count(*) FROM public.profiles q WHERE pg_catalog.lower(q.display_name)=pg_catalog.lower(p.display_name)
          AND q.is_active AND q.archived_at IS NULL AND q.role IN ('boxer','coach'))=1) x),'[]'::jsonb);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_card_gallery() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_card_gallery() TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
