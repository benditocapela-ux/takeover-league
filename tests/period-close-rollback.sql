\set ON_ERROR_STOP on
do $$begin if current_database() not like 'league21_replay_%' then raise exception 'Disposable fixture DB only';end if;end$$;
create temp table period_before as select md5(jsonb_build_object(
 'profiles',(select jsonb_agg(to_jsonb(p) order by id) from public.profiles p),
 'tx',(select jsonb_agg(to_jsonb(t) order by id) from public.point_transactions t),
 'seasons',(select jsonb_agg(to_jsonb(s) order by id) from public.league_seasons_v21 s),
 'results',(select jsonb_agg(to_jsonb(r) order by id) from public.league_season_results_v21 r),
 'honors',(select jsonb_agg(to_jsonb(h) order by id) from public.league_hall_of_fame_v21 h),
 'notices',(select jsonb_agg(to_jsonb(n) order by id) from public.boxer_notifications n))::text) fingerprint;
\ir ../supabase/production-prep/rollback_20261102095858_period_close_preview_snapshot.sql
do $$begin if to_regprocedure('public.league_period_close_confirm(text,text,boolean,text)') is not null or
 public.league_archive_period('month','2026-10',20,0)->>'source'<>'current_ledger_reconstruction' then raise exception 'Rollback incomplete';end if;end$$;
\ir ../supabase/migrations/20261102095858_period_close_preview_snapshot.sql
do $$declare after_value text;begin
 after_value:=md5(jsonb_build_object(
 'profiles',(select jsonb_agg(to_jsonb(p) order by id) from public.profiles p),
 'tx',(select jsonb_agg(to_jsonb(t) order by id) from public.point_transactions t),
 'seasons',(select jsonb_agg(to_jsonb(s) order by id) from public.league_seasons_v21 s),
 'results',(select jsonb_agg(to_jsonb(r) order by id) from public.league_season_results_v21 r),
 'honors',(select jsonb_agg(to_jsonb(h) order by id) from public.league_hall_of_fame_v21 h),
 'notices',(select jsonb_agg(to_jsonb(n) order by id) from public.boxer_notifications n))::text);
 if after_value is distinct from (select fingerprint from period_before) then raise exception 'Rollback/reapply changed existing records';end if;
end$$;
drop table period_before;
\echo Period close rollback/reapply preserves all existing profile/ledger/season/snapshot/honor/inbox data.
