BEGIN;
-- Etappe 8 (28.10.2026, Owner-Auftrag): kein separates Kampfgeist-Podium mehr.
-- * Wer auf dem normalen Podium (Top 3 des Monats) steht, entscheidet selbst, ob dort ein Emote neben dem eigenen Platz
--   erscheint, und wählt es aus den eigenen Emotes. Standard: kein Emote (nur wer es einschaltet, zeigt eines).
-- * get_podium_kampfgeist liefert dafür pro Platz nur noch «emote» (NULL, wenn ausgeschaltet) – keine Reaktionen und
--   keinen Look mehr. react_podium und die bisherigen Reaktionen bleiben in der Datenbank unverändert, werden aber nicht mehr angezeigt.
-- * Neue Funktion set_podium_emote(p_show, p_emote_key). Nur mit Kampfgeist-Shop (Flag) bzw. für den Admin.
-- Bestehende Daten bleiben unverändert.

DO $$ BEGIN
 IF to_regclass('public.kg_equipped') IS NULL OR to_regprocedure('league_private.kg_my_emotes(uuid)') IS NULL
    OR to_regprocedure('public.get_podium_kampfgeist()') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: 20261028220000_kampfgeist_etappe5';
 END IF;
END $$;

ALTER TABLE public.kg_equipped ADD COLUMN IF NOT EXISTS podium_emote boolean NOT NULL DEFAULT false;

-- Emote im Podium ein/aus und optional ein eigenes Emote wählen.
CREATE OR REPLACE FUNCTION public.set_podium_emote(p_show boolean, p_emote_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); it public.kg_items; ri integer; e public.kg_equipped;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('kampfgeist_shop') AND me.role<>'admin' THEN RAISE EXCEPTION 'Emotes sind noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF p_show IS NULL THEN RAISE EXCEPTION 'Bitte ein- oder ausschalten' USING ERRCODE='22023'; END IF;
 IF p_emote_key IS NOT NULL THEN
  SELECT * INTO it FROM public.kg_items x WHERE x.key=p_emote_key;
  IF NOT FOUND OR it.category<>'emote' THEN RAISE EXCEPTION 'Das ist kein Emote' USING ERRCODE='22023'; END IF;
  ri := league_private.kg_rank_idx(league_private.kg_level(league_private.kg_exp(me.id)));
  IF NOT league_private.kg_owns(me.id,it,ri) THEN RAISE EXCEPTION 'Dieses Emote gehört dir noch nicht' USING ERRCODE='42501'; END IF;
 END IF;
 INSERT INTO public.kg_equipped(profile_id) VALUES (me.id) ON CONFLICT (profile_id) DO NOTHING;
 UPDATE public.kg_equipped x SET podium_emote=p_show, emote=coalesce(p_emote_key,x.emote), updated_at=now()
 WHERE x.profile_id=me.id RETURNING * INTO e;
 RETURN pg_catalog.jsonb_build_object('show',e.podium_emote,'emote',league_private.kg_look(me.id)->'emote');
END;
$fn$;

-- Podium (Top 3 des Monats wie get_public_leaderboard): Emote nur, wenn die Person es eingeschaltet hat.
CREATE OR REPLACE FUNCTION public.get_podium_kampfgeist()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); on_ boolean := league_private.flag_on('kampfgeist_shop');
BEGIN
 IF me.id IS NULL THEN RETURN NULL; END IF;
 IF NOT on_ AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT on_,
  'my_show',coalesce((SELECT x.podium_emote FROM public.kg_equipped x WHERE x.profile_id=me.id),false),
  'my_emote',league_private.kg_look(me.id)->'emote',
  'my_emotes',league_private.kg_my_emotes(me.id),
  'places',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('rank',lb.rank_position,'name',p.display_name,'is_me',p.id=me.id,
     'show_emote',coalesce(q.podium_emote,false),
     'emote',CASE WHEN coalesce(q.podium_emote,false) THEN league_private.kg_look(p.id)->'emote' END)
     ORDER BY lb.rank_position)
   FROM (SELECT x.rank_position, x.boxer_name FROM public.get_public_leaderboard() x WHERE x.rank_position<=3 AND x.monthly_points>0) lb
   JOIN public.profiles p ON pg_catalog.lower(p.display_name)=pg_catalog.lower(lb.boxer_name) AND p.is_active AND p.archived_at IS NULL
   LEFT JOIN public.kg_equipped q ON q.profile_id=p.id),'[]'::jsonb));
END;
$fn$;

REVOKE ALL ON FUNCTION public.set_podium_emote(boolean,text), public.get_podium_kampfgeist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_podium_emote(boolean,text), public.get_podium_kampfgeist() TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
