-- READ ONLY postflight. No RPC is called and no rows are changed.
SELECT to_regprocedure('public.duel_v2_withdraw_invite(uuid)') AS withdraw_invite_rpc,
       has_function_privilege('anon','public.duel_v2_withdraw_invite(uuid)','EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated','public.duel_v2_withdraw_invite(uuid)','EXECUTE') AS authenticated_can_execute;
SELECT feature_key,is_enabled FROM public.league_feature_flags WHERE feature_key='duels';
SELECT status,count(*) AS duel_count FROM public.league_duels GROUP BY status ORDER BY status;
