-- READ ONLY preflight. Run against the intended database before any separately approved migration.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT
 to_regclass('public.league_coach_challenges') AS coach_challenges_table,
 to_regclass('public.league_coach_challenge_entries') AS coach_entries_table,
 to_regclass('public.league_global_challenges_v21') AS global_challenges_table,
 to_regclass('public.league_global_entries_v21') AS global_entries_table;
SELECT feature_key,is_enabled
FROM public.league_feature_flags
WHERE feature_key IN ('coach_challenges','league_challenges')
ORDER BY feature_key;
SELECT to_regprocedure('public.coach_challenge_v2_admin_edit(uuid,text,text,text,integer,text,integer)') AS coach_edit_rpc,
       to_regprocedure('public.league_v21_admin_edit_global_challenge(uuid,text,text,text,numeric,timestamp with time zone,timestamp with time zone,boolean)') AS global_edit_rpc;
