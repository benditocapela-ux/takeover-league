-- RÜCKNAHME 20261029130000_podium_emote.sql: Podium-Funktion wie in Etappe 5, set_podium_emote und Spalte podium_emote entfernen.
-- Nur ausführen, wenn das neue Podium (Etappe 8) zurückgenommen werden soll. Emote-Auswahl der Boxer (kg_equipped.emote) bleibt erhalten.
BEGIN;
DROP FUNCTION IF EXISTS public.set_podium_emote(boolean,text);
CREATE OR REPLACE FUNCTION public.get_podium_kampfgeist()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); on_ boolean := league_private.flag_on('kampfgeist_shop'); staff boolean; muted boolean;
 m date := league_private.kg_month(league_private.zurich_today()); today date := league_private.zurich_today();
BEGIN
 IF me.id IS NULL THEN RETURN NULL; END IF;
 IF NOT on_ AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 staff := league_private.kg_is_staff(me);
 muted := EXISTS (SELECT 1 FROM public.kg_emote_mutes x WHERE x.profile_id=me.id);
 RETURN pg_catalog.jsonb_build_object('enabled',true,'preview',NOT on_,'can_moderate',staff,'muted',muted,'month',m,
  'my_emotes',league_private.kg_my_emotes(me.id),
  'places',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('rank',lb.rank_position,'name',p.display_name,'is_me',p.id=me.id,
     'look',league_private.kg_look(p.id),
     'reactions',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('emote',league_private.kg_item_json(i),'count',r.n) ORDER BY r.n DESC, i.sort_order)
        FROM (SELECT e.emote_key, count(*) n FROM public.kg_emote_events e WHERE e.context='podium' AND e.month=m AND e.target_id=p.id AND e.hidden_at IS NULL GROUP BY e.emote_key) r
        JOIN public.kg_items i ON i.key=r.emote_key),'[]'::jsonb),
     'reacted_today',EXISTS (SELECT 1 FROM public.kg_emote_events e WHERE e.context='podium' AND e.sender_id=me.id AND e.target_id=p.id AND e.day=today),
     'can_react',on_ AND NOT muted AND p.id<>me.id AND NOT EXISTS (SELECT 1 FROM public.kg_emote_events e WHERE e.context='podium' AND e.sender_id=me.id AND e.target_id=p.id AND e.day=today))
     ORDER BY lb.rank_position)
   FROM (SELECT x.rank_position, x.boxer_name FROM public.get_public_leaderboard() x WHERE x.rank_position<=3 AND x.monthly_points>0) lb
   JOIN public.profiles p ON pg_catalog.lower(p.display_name)=pg_catalog.lower(lb.boxer_name) AND p.is_active AND p.archived_at IS NULL),'[]'::jsonb));
END;
$fn$;
REVOKE ALL ON FUNCTION public.get_podium_kampfgeist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_podium_kampfgeist() TO authenticated;
ALTER TABLE public.kg_equipped DROP COLUMN IF EXISTS podium_emote;
NOTIFY pgrst, 'reload schema';
COMMIT;
