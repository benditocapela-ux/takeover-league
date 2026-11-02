-- Read-only, no closure or payout.
select p.oid::regprocedure signature,p.prosecdef,p.provolatile,p.proconfig
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='league_archive_private' or (n.nspname='public' and p.proname='league_archive_period');
select has_function_privilege('anon','public.league_archive_period(text,text,integer,integer)','execute') public_reader,
 not has_function_privilege('anon','league_archive_private.period_rows(text,uuid,date,date,boolean)','execute') internal_rows_hidden;
select tablename,policyname,permissive,qual from pg_policies
where schemaname='public' and policyname in ('Archive results respect current visibility','Archive honors respect current visibility');
