-- READ ONLY; inspect structure and grants, never call confirm during postflight.
begin read only;
select jsonb_build_object(
 'preview',to_regprocedure('public.league_period_close_preview(text,text)') is not null,
 'confirm',to_regprocedure('public.league_period_close_confirm(text,text,boolean,text)') is not null,
 'anonymous_preview_denied',not has_function_privilege('anon','public.league_period_close_preview(text,text)','execute'),
 'anonymous_confirm_denied',not has_function_privilege('anon','public.league_period_close_confirm(text,text,boolean,text)','execute'),
 'authenticated_confirm_exposed_role_checked',has_function_privilege('authenticated','public.league_period_close_confirm(text,text,boolean,text)','execute'),
 'private_snapshot_read_denied',not has_table_privilege('authenticated','league_archive_private.month_results','select'),
 'private_snapshot_write_denied',not has_table_privilege('authenticated','league_archive_private.month_results','insert'),
 'month_immutable',exists(select 1 from pg_trigger where tgrelid='league_archive_private.month_results'::regclass and tgname='month_results_immutable' and tgenabled='O'),
 'snapshot_count',(select count(*) from league_archive_private.period_closures)
) as period_close_postflight;
rollback;
