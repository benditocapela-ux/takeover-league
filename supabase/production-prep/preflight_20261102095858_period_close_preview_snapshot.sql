-- READ ONLY; no personal values, tokens, writes or closes.
begin read only;
select jsonb_build_object(
 'archive_reader',to_regprocedure('public.league_archive_period(text,text,integer,integer)') is not null,
 'season_transition',to_regprocedure('league_v21_private.season_transition_core(uuid,text)') is not null,
 'notifications',to_regprocedure('league_v21_private.notifications_enabled()') is not null,
 'event_identity',exists(select 1 from information_schema.columns where table_schema='public' and table_name='boxer_notifications' and column_name='event_key'),
 'no_previous_month_closure_table',to_regclass('league_archive_private.period_closures') is null,
 'archive_profile_visibility_policy',exists(select 1 from pg_policies where schemaname='public' and tablename='league_season_results_v21' and policyname='Archive results respect current visibility'),
 'timezone','Europe/Zurich', 'new_bonus_configured',false
) as period_close_prerequisites;
rollback;
