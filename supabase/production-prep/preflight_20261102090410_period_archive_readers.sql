-- Read-only prerequisites, not a migration or release approval.
select current_database() database,current_setting('TimeZone') database_timezone,
 to_regclass('public.league_season_results_v21') season_results,
 to_regclass('public.league_hall_of_fame_v21') honors,
 to_regprocedure('auth.uid()') auth_uid;
select table_name,column_name,data_type from information_schema.columns
where table_schema='public' and ((table_name='profiles' and column_name in ('is_active','is_listed','archived_at','auth_user_id','role'))
 or (table_name='league_season_results_v21' and column_name in ('boxer_id','boxer_name','captured_at','season_id','rank_position','points','exp')))
order by table_name,column_name;
select tablename,policyname,permissive,roles,cmd,qual from pg_policies
where schemaname='public' and tablename in ('league_season_results_v21','league_hall_of_fame_v21');
