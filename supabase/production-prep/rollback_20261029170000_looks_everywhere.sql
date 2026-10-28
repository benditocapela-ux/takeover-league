-- Rücknahme von 20261029170000_looks_everywhere.sql: kg_look wieder exakt wie 20261028220000 (Standard «Schlicht»/«Rookie»),
-- get_public_boxer_looks entfernen. Es wurden keine Daten geändert, also gibt es nichts zurückzuschreiben.
BEGIN;
CREATE OR REPLACE FUNCTION league_private.kg_look(p uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE e public.kg_equipped; lvl integer := league_private.kg_level(league_private.kg_exp(p)); r jsonb := '{}'::jsonb; slot text; k text; it public.kg_items;
 defaults jsonb := '{"avatar":"a_kenji","aura":"u_none","banner":"b_dojo","rahmen":"f_none","titel":"t_rookie","handschuhe":"g_rot","emote":"m_respekt","einlauf":"e_slam"}';
BEGIN
 SELECT * INTO e FROM public.kg_equipped x WHERE x.profile_id=p;
 FOREACH slot IN ARRAY ARRAY['avatar','aura','banner','rahmen','titel','handschuhe','emote','einlauf'] LOOP
  k := CASE slot WHEN 'avatar' THEN e.avatar WHEN 'aura' THEN e.aura WHEN 'banner' THEN e.banner WHEN 'rahmen' THEN e.rahmen
                 WHEN 'titel' THEN e.titel WHEN 'handschuhe' THEN e.handschuhe WHEN 'emote' THEN e.emote ELSE e.einlauf END;
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
REVOKE ALL ON FUNCTION league_private.kg_look(uuid) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.get_public_boxer_looks();
NOTIFY pgrst, 'reload schema';
COMMIT;
