-- READ-ONLY, repeatable V2.1 production preflight.
-- Never creates anything, pays EXP or toggles a feature. Run before authorized release.
WITH checks AS (
 select
  (select count(*)=10 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname in
    ('profiles','point_transactions','training_submissions','training_types',
     'league_duels','league_duel_exp_ledger','league_coach_challenges',
     'achievement_definitions','boxer_achievements','league_feature_flags')
     and c.relkind='r') as required_baseline_tables,
  (select count(*)=0 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind in ('r','v','m')
      and c.relname like '%_v21') as v21_not_yet_installed,
  pg_catalog.to_regprocedure('public.duel_v2_reconcile(uuid)') is not null as duel_reconcile_available,
  (select count(*)>0 from public.profiles where role='admin' and is_active) as active_admin_exists,
  (select count(*)>=2 from public.profiles where role='boxer' and is_active) as at_least_two_boxers,
  (select count(*)=0 from public.training_submissions s
    where s.status='approved' and not exists
    (select 1 from public.point_transactions t
      where t.submission_id=s.id and t.boxer_id=s.boxer_id
        and t.category in ('training','legacy_import'))) as approved_training_has_ledger,
  (select count(*)=0 from
   (select t.submission_id from public.point_transactions t
     where t.submission_id is not null and t.category in ('training','legacy_import')
     group by t.submission_id having count(*)>1) dup) as no_duplicate_training_ledger,
  (select count(*)=2 from public.league_feature_flags
    where feature_key in ('coach_challenges','duels') and is_enabled) as original_v2_flags_active,
  not pg_catalog.has_table_privilege('anon','public.point_transactions','SELECT')
    as anon_cannot_read_private_ledger,
  not pg_catalog.has_table_privilege('authenticated','public.point_transactions','INSERT')
    as boxers_cannot_insert_ledger,
  (select count(*)=2 from pg_catalog.pg_attribute a
   join pg_catalog.pg_class c on c.oid=a.attrelid
   join pg_catalog.pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and
     ((c.relname='point_transactions' and a.attname='description')
      or (c.relname='training_submissions' and a.attname='notes'))
     and a.attnotnull and not a.attisdropped) as production_text_fields_not_null
), audit AS (
 select pg_catalog.to_jsonb(checks) as details,
   (required_baseline_tables and v21_not_yet_installed and duel_reconcile_available
    and active_admin_exists and at_least_two_boxers and approved_training_has_ledger
    and no_duplicate_training_ledger and original_v2_flags_active
    and anon_cannot_read_private_ledger and boxers_cannot_insert_ledger
    and production_text_fields_not_null) as passed
 from checks
)
select pg_catalog.jsonb_build_object(
 'release_21_schema_preflight_passed',passed,
 'checks',details,
 'notes','Read-only baseline validation only. Still requires login E2E, auth audit, backup/restore and approval.'
) as release_21_preflight from audit;
