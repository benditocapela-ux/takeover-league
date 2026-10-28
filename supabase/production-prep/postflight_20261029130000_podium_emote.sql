-- Read-only Postflight nach 20261029130000_podium_emote.sql (ändert nichts).
SELECT 'Spalte podium_emote, Standard aus' AS check_name, (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='kg_equipped'
  AND column_name='podium_emote' AND is_nullable='NO' AND column_default='false') AND NOT EXISTS (SELECT 1 FROM public.kg_equipped WHERE podium_emote))::text AS ok
UNION ALL SELECT 'set_podium_emote SECURITY DEFINER, nicht für anon', (EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
  AND p.proname='set_podium_emote' AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""'])
  AND NOT has_function_privilege('anon','public.set_podium_emote(boolean,text)','EXECUTE') AND NOT has_function_privilege('anon','public.get_podium_kampfgeist()','EXECUTE'))::text
UNION ALL SELECT 'Podium ohne Reaktionen und Look', (pg_get_functiondef('public.get_podium_kampfgeist()'::regprocedure) NOT LIKE '%reactions%'
  AND pg_get_functiondef('public.get_podium_kampfgeist()'::regprocedure) LIKE '%podium_emote%')::text
UNION ALL SELECT 'Referenz kg_equipped (Anzahl / Fingerabdruck)', (SELECT count(*)||' / '||md5(coalesce(string_agg(x::text,'|' ORDER BY profile_id),'')) FROM (SELECT profile_id,avatar,aura,banner,rahmen,titel,handschuhe,emote,einlauf FROM public.kg_equipped) x)
UNION ALL SELECT 'Referenz Podium-Reaktionen', (SELECT count(*)::text FROM public.kg_emote_events WHERE context='podium');
