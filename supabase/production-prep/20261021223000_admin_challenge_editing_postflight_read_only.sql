-- READ ONLY postflight. No feature flags are changed by this migration.
SELECT p.oid::regprocedure AS function_signature,
       n.nspname AS schema_name,
       p.prosecdef AS security_definer,
       has_function_privilege('anon',p.oid,'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.oid IN (
 to_regprocedure('public.coach_challenge_v2_admin_edit(uuid,text,text,text,integer,text,integer)'),
 to_regprocedure('public.league_v21_admin_edit_global_challenge(uuid,text,text,text,numeric,timestamp with time zone,timestamp with time zone,boolean)')
)
ORDER BY p.oid::regprocedure::text;
SELECT feature_key,is_enabled
FROM public.league_feature_flags
WHERE feature_key IN ('coach_challenges','league_challenges')
ORDER BY feature_key;
