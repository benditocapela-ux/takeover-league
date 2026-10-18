-- TAKEOVER LEAGUE 2.0 - READ-ONLY PREFLIGHT
-- Never changes data, roles, flags or schema.
select
  (select count(*) from public.profiles where role='boxer' and is_active) as active_boxers,
  (select count(*) from public.training_submissions where status='approved') as approved_trainings,
  (select count(*) from public.training_submissions where status='pending') as pending_trainings,
  (select count(*) from public.training_submissions s where s.status='approved' and not exists (
     select 1 from public.point_transactions t where t.submission_id=s.id and t.category in ('training','legacy_import')
  )) as approved_without_training_or_legacy_ledger,
  (select count(*) from public.point_transactions t join public.training_submissions s on s.id=t.submission_id
     where s.status='rejected' and (t.points<>0 or t.exp<>0)) as rejected_with_nonzero_linked_award,
  (select count(*) from (select submission_id from public.point_transactions
     where submission_id is not null group by submission_id having count(*)>1) q) as duplicate_submissions,
  to_regclass('public.training_drafts_v2') is not null as has_private_training_drafts,
  to_regclass('public.league_coach_challenge_targets') is not null as has_private_challenge_targeting;
select feature_key,is_enabled from public.league_feature_flags order by feature_key;
select proname, pg_get_function_result(p.oid) as result_type
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and proname in ('coach_challenge_v2_list','coach_challenge_v2_progress','review_training')
order by proname;
