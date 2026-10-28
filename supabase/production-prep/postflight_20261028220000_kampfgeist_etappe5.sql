-- Read-only Postflight nach 20261028220000_kampfgeist_etappe5.sql (ändert nichts).
SELECT '5 neue Tabellen vorhanden, RLS aktiv' AS check_name, ((SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relrowsecurity AND c.relname IN ('kg_pass_settings','kg_pass_tiers','kg_pass_claims','kg_emote_events','kg_emote_mutes'))=5)::text AS ok
UNION ALL SELECT 'Keine direkten Tabellenrechte', (NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='public'
  AND table_name IN ('kg_pass_settings','kg_pass_tiers','kg_pass_claims','kg_emote_events','kg_emote_mutes') AND grantee IN ('anon','authenticated','PUBLIC')))::text
UNION ALL SELECT '10 RPCs SECURITY DEFINER mit festem search_path', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('get_my_kampfpfad','claim_kampfpfad','get_duel_kampfgeist',
  'send_duel_emote','get_podium_kampfgeist','react_podium','hide_kg_emote','admin_set_emote_mute','admin_kg_social','admin_update_kg_pass'))=10)::text
UNION ALL SELECT 'anon darf keine RPC ausführen', (NOT has_function_privilege('anon','public.send_duel_emote(uuid,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.get_podium_kampfgeist()','EXECUTE') AND NOT has_function_privilege('anon','public.claim_kampfpfad(date,integer)','EXECUTE'))::text
UNION ALL SELECT 'Hilfsfunktionen gesperrt', (NOT has_function_privilege('authenticated','league_private.kg_pass_points(uuid,date)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.kg_my_emotes(uuid)','EXECUTE'))::text
UNION ALL SELECT 'Katalog: 145 Items (18 Emotes, 10 Einläufe, 5 Kampfpfad)', ((SELECT count(*) FROM public.kg_items)=145 AND (SELECT count(*) FROM public.kg_items WHERE category='emote')=18
  AND (SELECT count(*) FROM public.kg_items WHERE category='einlauf')=10 AND (SELECT count(*) FROM public.kg_items WHERE unlock='pass')=5)::text
UNION ALL SELECT 'Kampfpfad: 30 Stufen, 5 Items, Einstellungen 10/10/5/20/10/15 · 20 pro Stufe', ((SELECT count(*) FROM public.kg_pass_tiers)=30
  AND (SELECT count(*) FROM public.kg_pass_tiers WHERE item_key IS NOT NULL)=5
  AND EXISTS (SELECT 1 FROM public.kg_pass_settings WHERE kp_training=10 AND kp_quest_weekly=10 AND kp_quest_daily=5 AND kp_quest_chest=20 AND kp_duel_played=10 AND kp_duel_won=15 AND kp_per_tier=20))::text
UNION ALL SELECT 'kg_equipped hat emote und einlauf', ((SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='kg_equipped' AND column_name IN ('emote','einlauf'))=2)::text
UNION ALL SELECT 'Noch keine Emotes, Abholungen, Pausen', (NOT EXISTS (SELECT 1 FROM public.kg_emote_events) AND NOT EXISTS (SELECT 1 FROM public.kg_pass_claims) AND NOT EXISTS (SELECT 1 FROM public.kg_emote_mutes))::text;
