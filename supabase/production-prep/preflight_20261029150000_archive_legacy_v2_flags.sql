-- Read-only Preflight vor 20261029150000_archive_legacy_v2_flags.sql (ändert nichts).
SELECT '7 alte Schalter vorhanden und alle AUS' AS check_name, ((SELECT count(*) FROM public.league_feature_flags WHERE NOT is_enabled AND feature_key IN
  ('boxer_duels','coach_goals','hall_of_fame','league_challenges','palmares','public_boxer_profiles','seasons'))=7)::text AS ok
UNION ALL SELECT '9 alte Tabellen leer', ((SELECT count(*) FROM public.boxer_duels)+(SELECT count(*) FROM public.boxer_coach_goals)+(SELECT count(*) FROM public.league_hall_of_fame)
  +(SELECT count(*) FROM public.league_challenges)+(SELECT count(*) FROM public.league_challenge_participants)+(SELECT count(*) FROM public.boxer_palmares)
  +(SELECT count(*) FROM public.boxer_public_profile_details)+(SELECT count(*) FROM public.league_seasons)+(SELECT count(*) FROM public.league_season_results)=0)::text
UNION ALL SELECT '16 alte Funktionen in public', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
  ('boxer_join_league_challenge','boxer_respond_duel_invite','coach_add_boxer_palmares','coach_add_hall_of_fame_entry','coach_award_season_hall_of_fame',
   'coach_create_boxer_duel','coach_create_league_challenge','coach_create_league_season','coach_finalize_boxer_duel','coach_finalize_league_season',
   'coach_set_boxer_duel_status','coach_set_goal_status','coach_set_league_challenge_status','coach_set_league_season_status','get_boxer_duel_score',
   'get_league_challenge_progress'))=16)::text
UNION ALL SELECT 'Noch kein Archiv', (to_regnamespace('legacy_v2_archive') IS NULL)::text
UNION ALL SELECT 'Neue Strukturen da (Duelle, Coach-Challenges, Liga 2.1)', (to_regclass('public.league_duels') IS NOT NULL AND to_regclass('public.league_seasons_v21') IS NOT NULL
  AND to_regclass('public.league_global_challenges_v21') IS NOT NULL)::text
UNION ALL SELECT 'Referenz Schalter gesamt / an', (SELECT count(*)||' / '||count(*) FILTER (WHERE is_enabled) FROM public.league_feature_flags)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
