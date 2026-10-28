-- Etappe 11 (28.10.2026, Owner-Auftrag): Rahmen und Titel überall, wo ein Boxer zu sehen ist.
-- * league_private.kg_look: Wer für Rahmen oder Titel noch nichts ausgewählt hat, trägt automatisch das Rang-Emblem und den
--   Rang-Titel seines aktuellen Rangs (ab Rang E). Eine bewusste Auswahl (auch «Schlicht» bzw. «Rookie») bleibt unverändert.
--   Alles andere an kg_look ist identisch mit 20261028220000.
-- * public.get_public_boxer_looks(): Rahmen, Titel und Rang aller sichtbaren Boxer für Rangliste, Podium, Profil und
--   Gäste-Seite. Auch ohne Anmeldung (nur Design-Daten, keine Coins, keine Noten). Nur sichtbare Profile (is_listed),
--   dazu das eigene; Trainer und Admins sehen alle. Nur eindeutige Namen. Leer, solange der Kampfgeist-Shop aus ist.
-- Keine Daten werden geändert (keine Ausrüstung, keine Coins, keine Punkte).
BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.kg_look(uuid)') IS NULL OR to_regprocedure('league_private.kg_owns(uuid,public.kg_items,integer)') IS NULL
    OR to_regprocedure('league_private.kg_item_json(public.kg_items)') IS NULL OR to_regprocedure('league_private.active_viewer()') IS NULL
    OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='kg_equipped' AND column_name='einlauf')
    OR (SELECT count(*) FROM public.kg_items WHERE key IN ('f_rang_e','f_rang_d','f_rang_c','f_rang_b','f_rang_a','f_rang_s',
        't_prospect','t_contender','t_challenger','t_elite','t_champion','t_legend') AND unlock='rank')<>12 THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: Kampfgeist Etappe 5 (20261028220000) mit Rang-Rahmen und Rang-Titeln';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION league_private.kg_look(p uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE e public.kg_equipped; lvl integer := league_private.kg_level(league_private.kg_exp(p)); r jsonb := '{}'::jsonb; slot text; k text; it public.kg_items;
 ri integer := league_private.kg_rank_idx(lvl);
 defaults jsonb := '{"avatar":"a_kenji","aura":"u_none","banner":"b_dojo","rahmen":"f_none","titel":"t_rookie","handschuhe":"g_rot","emote":"m_respekt","einlauf":"e_slam"}';
BEGIN
 -- Ohne eigene Auswahl: Rang-Emblem und Rang-Titel (ab Rang E) statt «Schlicht» und «Rookie».
 IF ri>=1 THEN
  defaults := defaults || pg_catalog.jsonb_build_object(
   'rahmen',(ARRAY['f_rang_e','f_rang_d','f_rang_c','f_rang_b','f_rang_a','f_rang_s'])[ri],
   'titel',(ARRAY['t_prospect','t_contender','t_challenger','t_elite','t_champion','t_legend'])[ri]);
 END IF;
 SELECT * INTO e FROM public.kg_equipped x WHERE x.profile_id=p;
 FOREACH slot IN ARRAY ARRAY['avatar','aura','banner','rahmen','titel','handschuhe','emote','einlauf'] LOOP
  k := CASE slot WHEN 'avatar' THEN e.avatar WHEN 'aura' THEN e.aura WHEN 'banner' THEN e.banner WHEN 'rahmen' THEN e.rahmen
                 WHEN 'titel' THEN e.titel WHEN 'handschuhe' THEN e.handschuhe WHEN 'emote' THEN e.emote ELSE e.einlauf END;
  it := NULL;
  IF k IS NOT NULL THEN SELECT * INTO it FROM public.kg_items x WHERE x.key=k; END IF;
  IF it.key IS NULL OR NOT league_private.kg_owns(p,it,ri) THEN
   SELECT * INTO it FROM public.kg_items x WHERE x.key=defaults->>slot;
  END IF;
  r := r || pg_catalog.jsonb_build_object(slot, league_private.kg_item_json(it));
 END LOOP;
 RETURN r || pg_catalog.jsonb_build_object('level',lvl,'rank',(ARRAY['F','E','D','C','B','A','S'])[ri+1]);
END;
$fn$;
REVOKE ALL ON FUNCTION league_private.kg_look(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_public_boxer_looks()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); staff boolean;
BEGIN
 IF NOT league_private.flag_on('kampfgeist_shop') THEN RETURN '[]'::jsonb; END IF;
 staff := me.id IS NOT NULL AND me.role IN ('admin','coach');
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'name',p.display_name,'rank',lk->>'rank',
   'rahmen',CASE WHEN coalesce(lk->'rahmen'->'design'->>'fr','none')='none' THEN NULL
     ELSE pg_catalog.jsonb_build_object('key',lk->'rahmen'->>'key','name',lk->'rahmen'->>'name','design',lk->'rahmen'->'design') END,
   'titel',CASE WHEN lk->'titel'->>'key' IS NULL OR lk->'titel'->>'key'='t_rookie' THEN NULL
     ELSE pg_catalog.jsonb_build_object('key',lk->'titel'->>'key','name',lk->'titel'->>'name','rarity',lk->'titel'->>'rarity') END)
   ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p CROSS JOIN LATERAL (SELECT league_private.kg_look(p.id) AS lk) l
  WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')
    AND (p.is_listed IS TRUE OR p.id=me.id OR staff)
    AND (SELECT count(*) FROM public.profiles q WHERE pg_catalog.lower(q.display_name)=pg_catalog.lower(p.display_name)
         AND q.is_active AND q.archived_at IS NULL)=1),'[]'::jsonb);
END;
$fn$;
REVOKE ALL ON FUNCTION public.get_public_boxer_looks() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_boxer_looks() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
