-- Explicit rollback only. Keep existing profile acknowledgements; refuse their loss.
begin;
do $$begin if exists(select 1 from league_archive_private.period_notice_dismissals)
 then raise exception 'Profile acknowledgements exist: retain data and prepare forward repair' using errcode='55000';end if;end$$;
drop function public.league_period_notice_dismiss(text);
drop function public.league_period_notices();
drop function league_archive_private.notice_candidates();
drop table league_archive_private.period_notice_dismissals;
notify pgrst,'reload schema';
commit;
