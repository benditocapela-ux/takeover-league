-- READ ONLY preflight. Run against the intended database before a separately approved migration.
SELECT current_database() AS database_name,current_user AS database_role;
SELECT to_regclass('public.league_duels') AS duels_table,
       to_regclass('public.league_duel_events') AS duel_events_table,
       to_regclass('public.league_feature_flags') AS feature_flags_table;
SELECT feature_key,is_enabled FROM public.league_feature_flags WHERE feature_key='duels';
SELECT to_regprocedure('public.duel_v2_withdraw_invite(uuid)') AS withdraw_invite_rpc;
SELECT status,count(*) AS duel_count FROM public.league_duels GROUP BY status ORDER BY status;
