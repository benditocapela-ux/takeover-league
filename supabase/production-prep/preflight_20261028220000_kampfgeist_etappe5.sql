-- Read-only Preflight vor 20261028220000_kampfgeist_etappe5.sql (ändert nichts).
SELECT 'Voraussetzung Etappe 4 (kg_sync, kg_items) und league_duels, get_public_leaderboard' AS check_name,
  (to_regprocedure('league_private.kg_sync(uuid)') IS NOT NULL AND to_regclass('public.kg_items') IS NOT NULL
   AND to_regclass('public.league_duels') IS NOT NULL AND to_regprocedure('public.get_public_leaderboard()') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Prüfregeln heissen wie erwartet', ((SELECT count(*) FROM pg_constraint WHERE conname IN ('kg_items_category_check','kg_items_unlock_check','kg_ledger_reason_check'))=3)::text
UNION ALL SELECT 'league_duels mit settled_at/winner_id', ((SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='league_duels'
   AND column_name IN ('settled_at','winner_id','accepted_at','challenger_id','opponent_id','status'))=6)::text
UNION ALL SELECT 'Neue Tabellen noch nicht vorhanden', (to_regclass('public.kg_pass_tiers') IS NULL AND to_regclass('public.kg_pass_claims') IS NULL
   AND to_regclass('public.kg_emote_events') IS NULL AND to_regclass('public.kg_emote_mutes') IS NULL AND to_regclass('public.kg_pass_settings') IS NULL)::text
UNION ALL SELECT 'Keine gleichnamigen RPCs', (NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND p.proname IN ('get_my_kampfpfad','claim_kampfpfad','get_duel_kampfgeist','send_duel_emote','get_podium_kampfgeist','react_podium','hide_kg_emote','admin_set_emote_mute','admin_kg_social','admin_update_kg_pass')))::text
UNION ALL SELECT 'Flag kampfgeist_shop (Stand)', coalesce((SELECT is_enabled::text FROM public.league_feature_flags WHERE feature_key='kampfgeist_shop'),'fehlt')
UNION ALL SELECT 'Referenz Trainings / Buchungen / EXP / Punkte', (SELECT count(*) FROM public.training_submissions WHERE status='approved')||' / '||(SELECT count(*)||' / '||sum(exp)||' / '||sum(points) FROM public.point_transactions)
UNION ALL SELECT 'Referenz Coin-Buch / Inventar / Items', (SELECT count(*) FROM public.kg_ledger)||' / '||(SELECT count(*) FROM public.kg_inventory)||' / '||(SELECT count(*) FROM public.kg_items);
