-- READ ONLY preflight/postflight for 20261028120000_revoke_unused_legacy_rpcs.sql.
-- Vorher: authenticated=true für alle 16; nachher: false. Aktive RPCs (z. B. review_training) bleiben true.
SELECT p.proname, has_function_privilege('authenticated',p.oid,'execute') AS authenticated, has_function_privilege('anon',p.oid,'execute') AS anon
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('boxer_join_league_challenge','boxer_respond_duel_invite','coach_add_boxer_palmares','coach_add_hall_of_fame_entry',
 'coach_award_season_hall_of_fame','coach_create_boxer_duel','coach_create_league_challenge','coach_create_league_season','coach_finalize_boxer_duel',
 'coach_finalize_league_season','coach_set_boxer_duel_status','coach_set_goal_status','coach_set_league_challenge_status','coach_set_league_season_status',
 'get_boxer_duel_score','get_league_challenge_progress','review_training')
ORDER BY 1;
