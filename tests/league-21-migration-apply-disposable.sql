-- DISPOSABLE PostgreSQL ONLY: commit V2.1 into a prepared league21_replay_* test DB.
-- This is exclusively for automated CI backup/restore rehearsal. Never execute on production.
\set ON_ERROR_STOP on
BEGIN;
DO $safety$ BEGIN
 if current_database() not like 'league21_replay_%'
 or current_user<>'postgres'
 then raise exception 'Refusing replay outside disposable league21_replay_* postgres database'
 using errcode='42501';end if;
 if pg_catalog.to_regclass('public.league_duels') is null
 or pg_catalog.to_regclass('public.training_submissions') is null
 or pg_catalog.to_regclass('public.point_transactions') is null
 or pg_catalog.to_regclass('public.boxer_achievements') is null
 or pg_catalog.to_regclass('public.achievement_definitions') is null
 then raise exception 'Incomplete V2 foundation: create production-like fixture first';end if;
 if pg_catalog.to_regclass('public.league_seasons_v21') is not null
 then raise exception 'V2.1 already exists. Need a clean, disposable V2 baseline';end if;
END $safety$;
\i supabase/migrations/20261019010000_league_21_seasons_goals_history_foundation.sql
\i supabase/migrations/20261019011000_league_21_goal_authorized_rpcs.sql
\i supabase/migrations/20261019012000_league_21_admin_achievement_backfill.sql
\i supabase/migrations/20261019014000_league_21_global_challenges.sql
\i supabase/migrations/20261019015000_league_21_season_admin_closure.sql
\i supabase/migrations/20261019016000_league_21_global_challenge_admin_creation.sql
\i supabase/migrations/20261019017000_league_21_admin_draft_read.sql
\i supabase/migrations/20261019018000_league_21_public_badge_projection.sql
\i supabase/migrations/20261019019000_league_21_public_records_projection.sql
\i supabase/migrations/20261019020000_league_21_global_challenge_close.sql
\i supabase/migrations/20261019021000_league_21_goal_completion.sql
\i supabase/migrations/20261019022000_league_21_goal_exp_ledger.sql
\i supabase/migrations/20261019023000_league_21_goal_reward_reversal.sql
\i supabase/migrations/20261019024000_league_21_global_settlement_review_gate.sql
\i supabase/migrations/20261019025000_league_21_multiboxer_arena.sql
\i supabase/migrations/20261019026000_league_21_multiboxer_live_scores.sql
\i supabase/migrations/20261019027000_league_21_global_exp_rewards.sql
\i supabase/migrations/20261019028000_league_21_ranked_duel_exp.sql
\i supabase/migrations/20261019029000_league_21_goal_review_reconciliation.sql
\i supabase/migrations/20261019030000_league_21_public_duel_history.sql
\i supabase/migrations/20261019031000_league_21_season_fair_close.sql
\i supabase/migrations/20261019032000_league_21_settlement_review_serialization.sql
\i supabase/migrations/20261019033000_league_21_goal_training_corrections.sql
\i supabase/migrations/20261019034000_league_21_goal_actual_exp_response.sql
DO $assert$ BEGIN
 IF (SELECT count(*) FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' and c.relname like '%_v21'
    and c.relkind='r' and c.relrowsecurity)<>17
 THEN raise exception 'Migration missing one of 17 RLS-protected V2.1 tables';end if;
END $assert$;
COMMIT;
\i supabase/production-prep/league_21_postflight_read_only.sql
