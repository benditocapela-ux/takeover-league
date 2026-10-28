-- Read-only Preflight vor 20261029130000_podium_emote.sql (ändert nichts).
SELECT 'Kampfgeist Etappe 5 vorhanden' AS check_name, (to_regclass('public.kg_equipped') IS NOT NULL AND to_regprocedure('league_private.kg_my_emotes(uuid)') IS NOT NULL
  AND to_regprocedure('public.get_podium_kampfgeist()') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Noch keine Podium-Emote-Einstellung', (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='kg_equipped' AND column_name='podium_emote')
  AND to_regprocedure('public.set_podium_emote(boolean,text)') IS NULL)::text
UNION ALL SELECT 'Referenz kg_equipped (Anzahl / Fingerabdruck)', (SELECT count(*)||' / '||md5(coalesce(string_agg(x::text,'|' ORDER BY profile_id),'')) FROM (SELECT profile_id,avatar,aura,banner,rahmen,titel,handschuhe,emote,einlauf FROM public.kg_equipped) x)
UNION ALL SELECT 'Referenz Podium-Reaktionen', (SELECT count(*)::text FROM public.kg_emote_events WHERE context='podium');
