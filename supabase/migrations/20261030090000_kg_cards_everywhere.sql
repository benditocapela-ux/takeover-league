-- Etappe 19 (29.10.2026, Owner-Auftrag): Die Kampfgeist-Anzeige (Banner, Avatar mit Aura und Rahmen, Titel, Name, Rang und Level)
-- auch im Ranking, im Boxerprofil, im Studio und auf dem Podium.
-- * public.get_public_boxer_cards(): pro sichtbarem Boxer das komplette Aussehen (nur Design-Daten der ausgerüsteten Items:
--   key, name, rarity, design – keine Preise, keine Coins, kein Inventar) plus Level und Rang. Dazu 'own_avatar': ob der Boxer
--   selbst einen Avatar gewählt hat (sonst zeigen die Seiten weiterhin sein Profilbild).
--   Sichtbarkeit wie get_public_boxer_looks (Etappe 11): auch für Gäste, nur sichtbare Profile (is_listed), dazu das eigene;
--   Trainer und Admins sehen alle; nur eindeutige Namen; leer, solange der Kampfgeist-Shop aus ist.
-- Nur lesend: keine Ausrüstung, keine Coins, keine Punkte, keine EXP werden geändert.
BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.kg_look(uuid)') IS NULL OR to_regprocedure('league_private.active_viewer()') IS NULL
    OR to_regprocedure('league_private.flag_on(text)') IS NULL OR to_regprocedure('public.get_public_boxer_looks()') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Kampfgeist mit öffentlichen Looks (20261029170000)';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.get_public_boxer_cards()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); staff boolean;
BEGIN
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RETURN '[]'::jsonb; END IF;
 staff := me.id IS NOT NULL AND me.role IN ('admin','coach');
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'name',p.display_name,'level',(lk->>'level')::integer,'rank',lk->>'rank',
   'own_avatar',coalesce(e.avatar IS NOT NULL AND e.avatar=lk->'avatar'->>'key',false),
   'avatar',(SELECT pg_catalog.jsonb_build_object('key',i->>'key','name',i->>'name','rarity',i->>'rarity','design',i->'design') FROM (SELECT lk->'avatar' AS i) s WHERE i IS NOT NULL),
   'aura',(SELECT pg_catalog.jsonb_build_object('key',i->>'key','name',i->>'name','rarity',i->>'rarity','design',i->'design') FROM (SELECT lk->'aura' AS i) s WHERE i IS NOT NULL),
   'banner',(SELECT pg_catalog.jsonb_build_object('key',i->>'key','name',i->>'name','rarity',i->>'rarity','design',i->'design') FROM (SELECT lk->'banner' AS i) s WHERE i IS NOT NULL),
   'rahmen',(SELECT pg_catalog.jsonb_build_object('key',i->>'key','name',i->>'name','rarity',i->>'rarity','design',i->'design') FROM (SELECT lk->'rahmen' AS i) s WHERE i IS NOT NULL),
   'titel',(SELECT pg_catalog.jsonb_build_object('key',i->>'key','name',i->>'name','rarity',i->>'rarity','design',i->'design') FROM (SELECT lk->'titel' AS i) s WHERE i IS NOT NULL),
   'handschuhe',(SELECT pg_catalog.jsonb_build_object('key',i->>'key','name',i->>'name','rarity',i->>'rarity','design',i->'design') FROM (SELECT lk->'handschuhe' AS i) s WHERE i IS NOT NULL))
   ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p CROSS JOIN LATERAL (SELECT league_private.kg_look(p.id) AS lk) l
  LEFT JOIN public.kg_equipped e ON e.profile_id=p.id
  WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')
    AND (p.is_listed IS TRUE OR p.id=me.id OR staff)
    AND (SELECT count(*) FROM public.profiles q WHERE pg_catalog.lower(q.display_name)=pg_catalog.lower(p.display_name)
         AND q.is_active AND q.archived_at IS NULL)=1),'[]'::jsonb);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_public_boxer_cards() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_boxer_cards() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
