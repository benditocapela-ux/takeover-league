begin read only;
select jsonb_build_object('period_closures',to_regclass('league_archive_private.period_closures') is not null,
 'notification_identity',exists(select 1 from information_schema.columns where table_schema='public' and table_name='boxer_notifications' and column_name='event_key'),
 'notice_reader_installed',to_regprocedure('public.league_period_notices()') is not null,
 'dismissal_installed',to_regprocedure('public.league_period_notice_dismiss(text)') is not null,
 'private_state_installed',to_regclass('league_archive_private.period_notice_dismissals') is not null) as period_notice_structure;
select n.nspname,p.proname,p.prosecdef,p.proconfig,p.proacl from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('league_period_notices','league_period_notice_dismiss');
rollback;
