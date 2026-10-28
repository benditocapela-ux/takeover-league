-- Rollback für 20261028220000_kampfgeist_etappe5.sql
-- Entfernt die neuen Funktionen und stellt kg_look/equip_kg_item aus Etappe 4 wieder her.
-- Daten bleiben: Emote-/Einlauf-/Kampfpfad-Items, Kampfpfad-Abholungen, Emote-Ereignisse, Pausen, Einstellungen,
-- erweiterte Prüfregeln und die Spalten emote/einlauf in kg_equipped (werden ohne Etappe 5 einfach nicht genutzt).
BEGIN;
DROP FUNCTION IF EXISTS public.admin_update_kg_pass(integer,integer,integer,integer,integer,integer,integer);
DROP FUNCTION IF EXISTS public.admin_kg_social();
DROP FUNCTION IF EXISTS public.admin_set_emote_mute(uuid,boolean);
DROP FUNCTION IF EXISTS public.hide_kg_emote(bigint);
DROP FUNCTION IF EXISTS public.react_podium(text,text);
DROP FUNCTION IF EXISTS public.get_podium_kampfgeist();
DROP FUNCTION IF EXISTS public.send_duel_emote(uuid,text);
DROP FUNCTION IF EXISTS public.get_duel_kampfgeist(uuid[]);
DROP FUNCTION IF EXISTS public.claim_kampfpfad(date,integer);
DROP FUNCTION IF EXISTS public.get_my_kampfpfad(date);
DROP FUNCTION IF EXISTS league_private.kg_duel_open(public.league_duels);
DROP FUNCTION IF EXISTS league_private.kg_my_emotes(uuid);
DROP FUNCTION IF EXISTS league_private.kg_emote_json(public.kg_emote_events,boolean);
DROP FUNCTION IF EXISTS league_private.kg_is_staff(public.profiles);
DROP FUNCTION IF EXISTS league_private.kg_pass_reward(uuid,public.kg_pass_tiers);
DROP FUNCTION IF EXISTS league_private.kg_pass_points(uuid,date);
DROP FUNCTION IF EXISTS league_private.kg_month(date);
-- Etappe-4-Fassungen wiederherstellen
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
NOTIFY pgrst, 'reload schema';
COMMIT;
