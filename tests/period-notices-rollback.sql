\set ON_ERROR_STOP on
do $$begin if current_database() not like 'league21_replay_%' then raise exception 'Disposable DB only';end if;end$$;
create temp table notices_before as select md5(coalesce(jsonb_agg(to_jsonb(n) order by id)::text,'[]')) fingerprint from public.boxer_notifications n;
\ir ../supabase/production-prep/rollback_20261102101922_period_notices_profile_state.sql
\ir ../supabase/migrations/20261102101922_period_notices_profile_state.sql
do $$begin if (select fingerprint from notices_before) is distinct from (select md5(coalesce(jsonb_agg(to_jsonb(n) order by id)::text,'[]')) from public.boxer_notifications n)
 then raise exception 'Rollback/reapply changed inbox state';end if;end$$;
drop table notices_before;
\echo Period notice rollback/reapply preserves existing inbox state.
