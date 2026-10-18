-- READ-ONLY V2.1 postflight: use after staging SQL replay and again after authorized production migration.
-- Inspect effective client grants and RLS; NEVER award EXP, change feature flags or modify data.
WITH expected(name,expose_anon) AS (
 values
 ('league_arena_duels_v21',false),
 ('league_arena_members_v21',false),
 ('league_arena_results_v21',false),
 ('league_boxer_goals_v21',false),
 ('league_duel_rank_snapshots_v21',false),
 ('league_global_challenges_v21',true),
 ('league_global_entries_v21',false),
 ('league_global_exp_ledger_v21',false),
 ('league_global_results_v21',true),
 ('league_goal_exp_ledger_v21',false),
 ('league_goal_progress_v21',false),
 ('league_hall_of_fame_v21',true),
 ('league_public_badges_v21',true),
 ('league_public_duel_history_v21',true),
 ('league_public_records_v21',true),
 ('league_season_results_v21',true),
 ('league_seasons_v21',true)
), table_checks AS (
 select count(c.oid)=17 as all_v21_tables_exist,
  bool_and(c.relrowsecurity) as every_v21_table_has_rls,
  bool_and(not has_table_privilege('anon',c.oid,'INSERT,UPDATE,DELETE')
    and not has_table_privilege('authenticated',c.oid,'INSERT,UPDATE,DELETE')) as no_direct_client_v21_writes,
  bool_and(has_table_privilege('anon',c.oid,'SELECT')=e.expose_anon) as anon_projection_grants_are_exact,
  bool_and(not has_table_privilege('authenticated',c.oid,'SELECT') or c.relrowsecurity) as all_authenticated_selects_are_rls_protected
 from expected e
 left join pg_catalog.pg_class c
   on c.oid=pg_catalog.to_regclass('public.'||e.name)
), auth_checks AS (
 select
  count(*)>=15 as all_public_v21_rpcs_present,
  bool_and(not p.prosecdef and not has_function_privilege('anon',p.oid,'EXECUTE')) as public_v21_rpc_restricted_to_signed_in
 from pg_catalog.pg_proc p
 join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname like 'league_v21_%'
), trigger_checks AS (
 select count(*)=3 as essential_triggers_present
 from pg_catalog.pg_trigger t where not t.tgisinternal and
 t.tgname in (
 'league_v21_goal_after_training_review',
 'league_v21_public_duel_history',
 'league_v21_public_duel_history_insert'
 )

), security_checks AS (
 select
 (select count(*)>=27 from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='league_v21_private' and p.prosecdef) as v21_private_definers_exist,
 (select count(*)=0 from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='league_v21_private' and p.prosecdef
    and (pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE')
      or not (p.proconfig @> ARRAY['search_path=""']::text[])))
 as v21_private_definers_locked_to_safe_path,
 (not pg_catalog.has_schema_privilege('anon','league_v21_private','USAGE')) as v21_private_schema_hidden_from_anon,
 (select count(*)=0 from pg_catalog.pg_class c
   join pg_catalog.pg_namespace n on n.oid=c.relnamespace
   join pg_catalog.pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
   where n.nspname='public' and c.relkind='r'
    and c.relname in (
     'league_global_challenges_v21','league_global_results_v21',
     'league_hall_of_fame_v21','league_public_badges_v21',
     'league_public_duel_history_v21','league_public_records_v21',
     'league_season_results_v21','league_seasons_v21')
    and lower(a.attname) in
      ('auth_user_id','email','password','phone','weight','notes',
       'raw_user_meta_data','raw_app_meta_data')) as public_projections_hide_sensitive_columns
), ledger_checks AS (
 select
  not exists(
    select 1 from public.league_goal_exp_ledger_v21 l
    left join public.point_transactions t on t.id=l.transaction_id
    where t.id is null or t.boxer_id<>l.boxer_id or t.category<>'challenge_exp'
      or t.points<>0 or t.exp not in (0,l.exp_amount)
  ) as goal_exp_ledger_integrity,
  not exists(
    select 1 from public.league_global_exp_ledger_v21 l
    left join public.point_transactions t on t.id=l.transaction_id
    where t.id is null or t.boxer_id<>l.boxer_id or t.category<>'challenge_exp'
      or t.points<>0 or t.exp<>l.exp_amount
  ) as global_exp_ledger_integrity
), flags AS (
 select (select count(*) from public.league_feature_flags f
   where f.feature_key in ('duels','coach_challenges'))=2
 as original_v2_flags_still_present
), audit AS (
 select pg_catalog.to_jsonb(table_checks)||pg_catalog.to_jsonb(auth_checks)
   ||pg_catalog.to_jsonb(trigger_checks)||pg_catalog.to_jsonb(security_checks)||pg_catalog.to_jsonb(ledger_checks)
   ||pg_catalog.to_jsonb(flags) as checks,
 (all_v21_tables_exist and every_v21_table_has_rls and no_direct_client_v21_writes
 and anon_projection_grants_are_exact and all_authenticated_selects_are_rls_protected
 and all_public_v21_rpcs_present and public_v21_rpc_restricted_to_signed_in
 and essential_triggers_present and v21_private_definers_exist
 and v21_private_definers_locked_to_safe_path and v21_private_schema_hidden_from_anon
 and public_projections_hide_sensitive_columns and goal_exp_ledger_integrity and global_exp_ledger_integrity
 and original_v2_flags_still_present) as passed
 from table_checks,auth_checks,trigger_checks,security_checks,ledger_checks,flags
)
select pg_catalog.jsonb_build_object('release_21_postflight_passed',passed,'checks',checks,
 'warning','This does not replace authenticated end-to-end testing or database restore rehearsal.') as v21_postflight
from audit;