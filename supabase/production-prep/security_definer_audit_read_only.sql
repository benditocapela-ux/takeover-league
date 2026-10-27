-- READ ONLY: SECURITY-DEFINER-Prüfung aller über die API aufrufbaren Funktionen (Schema public).
-- Erwartung: keine Zeile mit auth_check = 'PRÜFEN'. Öffentliche (anon) Funktionen nur lesend und auf is_listed gefiltert.
SELECT p.proname,
 has_function_privilege('anon',p.oid,'execute') AS anon,
 has_function_privilege('authenticated',p.oid,'execute') AS authenticated,
 CASE WHEN position('auth.uid' in pg_get_functiondef(p.oid))>0 THEN 'auth.uid()'
      WHEN position('coach_v2_actor' in pg_get_functiondef(p.oid))>0 THEN 'coach_v2_actor()'
      WHEN position('is_league_admin' in pg_get_functiondef(p.oid))>0 OR position('is_league_coach' in pg_get_functiondef(p.oid))>0 THEN 'is_league_admin/coach()'
      WHEN position('public.admin_edit_training(' in pg_get_functiondef(p.oid))>0 THEN 'delegiert an admin_edit_training'
      WHEN p.proname IN ('get_award_leaderboard','get_monthly_awards','get_public_boxer_avatars','get_public_leaderboard','get_public_levels')
       AND position('is_listed' in pg_get_functiondef(p.oid))>0 THEN 'öffentlich lesend (nur is_listed)'
      ELSE 'PRÜFEN' END AS auth_check,
 coalesce((SELECT string_agg(DISTINCT m[1],',') FROM regexp_matches(pg_get_functiondef(p.oid),'feature_key\s*=\s*''([a-z_]+)''','g') m),'') AS flags
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prosecdef AND p.prokind='f'
  AND (has_function_privilege('authenticated',p.oid,'execute') OR has_function_privilege('anon',p.oid,'execute'))
ORDER BY (CASE WHEN position('auth.uid' in pg_get_functiondef(p.oid))>0 THEN 1 ELSE 0 END), 1;
-- Private Kernfunktionen sind nicht über die API erreichbar (Schema nicht exponiert), aber nur für authenticated ausführbar:
SELECT p.proname, array_to_string(p.proacl,' ') AS acl FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname IN ('league_v21_private','league_private') AND has_function_privilege('anon',p.oid,'execute');
