-- Explicit authorized rollback only. Restore previous historical visibility;
-- deploy the matching old frontend with it. Never removes snapshot/ledger rows.
begin;
drop function if exists public.league_archive_period(text,text,integer,integer);
drop function if exists league_archive_private.period_core(text,text,integer,integer);
drop function if exists league_archive_private.period_rows(text,uuid,date,date,boolean);
drop policy if exists "Archive results respect current visibility" on public.league_season_results_v21;
drop policy if exists "Archive honors respect current visibility" on public.league_hall_of_fame_v21;
drop function if exists league_archive_private.profile_visible(uuid);
-- Intentionally no CASCADE: future objects must prevent an unsafe schema removal.
drop schema if exists league_archive_private;
commit;
