"""Challenge V2 review-only migration safety invariants."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
FILES = {
    n: (MIGRATIONS / f"{n:03d}_{suffix}.sql").read_text(encoding="utf-8")
    for n, suffix in (
        (11, "coach_challenges_v2_schema_review"),
        (12, "coach_challenges_v2_enrollment_rpc_review"),
        (13, "coach_challenges_v2_management_rpc_review"),
        (14, "coach_challenges_v2_withdraw_rpc_review"),
        (15, "coach_challenges_v2_read_rpc_review"),
        (16, "coach_challenges_v2_edit_draft_rpc_review"),
        (17, "coach_challenges_v2_goal_definition_rpc_review"),
        (18, "coach_challenges_v2_progress_rpc_review"),
        (19, "coach_challenges_v2_manual_review_rpc_review"),
        (20, "coach_challenges_v2_review_read_rpc_review"),
        (21, "coach_challenges_v2_review_candidates_rpc_review"),
        (22, "coach_challenges_v2_activation_rpc_review"),
        (23, "coach_challenges_v2_begin_reviews_rpc_review"),
        (25, "coach_challenges_v2_reward_config_review"),
        (26, "coach_challenges_v2_atomic_goal_reward_review"),
        (27, "coach_challenges_v2_manual_settlement_review"),
    )
}


def test_all_challenge_migrations_explicitly_review_only():
    for sql in FILES.values():
        assert "REVIEW ONLY" in sql
        assert "BEGIN;" in sql
        assert "COMMIT;" in sql


def test_challenge_feature_defaults_off_and_tables_private():
    sql = FILES[11]
    assert "VALUES('coach_challenges',false)" in sql
    for table in (
        "league_coach_challenges",
        "league_coach_challenge_entries",
        "league_coach_challenge_exp_ledger",
    ):
        assert f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY;" in sql
        assert f"REVOKE ALL ON public.{table} FROM PUBLIC,anon,authenticated;" in sql


def test_all_challenge_rpcs_are_locked_down():
    functions = {
        12: ("coach_challenge_v2_create_draft", "coach_challenge_v2_join"),
        13: ("coach_challenge_v2_manage",),
        14: ("coach_challenge_v2_withdraw",),
        15: ("coach_challenge_v2_list",),
        16: ("coach_challenge_v2_edit_draft",),
        17: ("coach_challenge_v2_set_goal",),
        18: ("coach_challenge_v2_progress",),
        19: ("coach_challenge_v2_review_manual",),
        20: ("coach_challenge_v2_review_status",),
        21: ("coach_challenge_v2_review_candidates",),
        22: ("coach_challenge_v2_activate",),
        23: ("coach_challenge_v2_begin_reviews",),
        25: ("coach_challenge_v2_set_reward",),
        26: ("coach_challenge_v2_save_goal_reward",),
        27: ("coach_challenge_v2_settle_manual",),
    }
    for migration, names in functions.items():
        sql = FILES[migration]
        assert sql.count("SECURITY DEFINER SET search_path TO ''") == len(names)
        for name in names:
            assert f"REVOKE ALL ON FUNCTION public.{name}(" in sql
            assert f"GRANT EXECUTE ON FUNCTION public.{name}(" in sql
            assert "auth.uid()" in sql


def test_no_challenge_payout_or_activation_implemented_without_goals():
    combined = "\n".join(FILES.values())
    pre_settlement = "\\n".join(sql for n, sql in FILES.items() if n != 27)
    assert "INSERT INTO public.point_transactions" not in pre_settlement
    assert "UPDATE public.point_transactions" not in pre_settlement
    assert "INSERT INTO public.league_coach_challenge_exp_ledger" not in pre_settlement


def test_goal_definition_requires_coach_and_keeps_payouts_disabled():
    sql = FILES[17]
    assert "p_review_mode NOT IN ('manual','automatic')" in sql
    assert "challenge.status<>'draft'" in sql
    assert "challenge.created_by<>actor.id" in sql
    assert "p_target_value<=0" in sql
    assert "p_metric NOT IN" in sql
    assert "jogging_km" in sql and "technique_minutes" in sql
    assert "jsonb_build_object" in sql


def test_progress_is_read_only_and_uses_approved_training():
    sql = FILES[18]
    assert "s.status='approved'" in sql
    assert "s.training_date" in sql
    assert "e.status='joined'" in sql
    assert "actor.role<>'boxer' OR e.boxer_id=actor.id" in sql
    assert "INSERT INTO" not in sql
    assert "UPDATE public.point_transactions" not in sql


def test_manual_review_is_private_audited_and_never_pays_exp():
    sql = FILES[19]
    assert "league_coach_challenge_reviews ENABLE ROW LEVEL SECURITY" in sql
    assert "reviewed_by" in sql and "reason text NOT NULL" in sql
    assert "UNIQUE(challenge_id,boxer_id)" in sql
    assert "Review already recorded" in sql
    assert "c.status<>'awaiting_reviews'" in sql
    assert "INSERT INTO public.point_transactions" not in sql


def test_review_status_limits_boxers_to_own_decision_and_hides_reason():
    sql = FILES[20]
    assert "v.boxer_id=actor.id" in sql
    assert "THEN NULL::text ELSE v.reason" in sql
    assert "c.created_by<>actor.id" in sql
    assert "INSERT INTO" not in sql and "UPDATE public." not in sql


def test_activation_requires_goal_enrollment_owner_and_row_lock():
    sql = FILES[22]
    assert "FOR UPDATE" in sql
    assert "c.created_by<>actor.id" in sql
    assert "c.status<>'open'" in sql
    assert "c.goal_spec IS NULL" in sql
    assert "status='joined'" in sql
    assert "v_now+(duration_days * interval '1 day')" in sql
    assert "c.goal_spec->>'review_mode' IS DISTINCT FROM 'manual'" in sql
    assert "c.goal_spec->>'reward_exp' IS NULL" in sql
    assert "c.goal_spec->>'version' IS DISTINCT FROM '1'" in sql
    assert "INSERT INTO public.point_transactions" not in sql


def test_review_transition_requires_expiry_and_owner():
    sql = FILES[23]
    assert "FOR UPDATE" in sql
    assert "c.created_by<>actor.id" in sql
    assert "c.status<>'active'" in sql
    assert "c.ends_at>pg_catalog.clock_timestamp()" in sql
    assert "status='awaiting_reviews'" in sql


def test_candidate_roster_only_for_creator_and_unreviewed_joined_boxers():
    sql = FILES[21]
    assert "challenge.created_by<>actor.id" in sql
    assert "challenge.status<>'awaiting_reviews'" in sql
    assert "e.status='joined'" in sql
    assert "NOT EXISTS" in sql
    assert "league_coach_challenge_reviews" in sql


def test_manual_settlement_remains_policy_gated():
    policy = (MIGRATIONS / "024_coach_challenges_v2_manual_settlement_policy_review.sql").read_text(encoding="utf-8")
    assert "REVIEW ONLY" in policy
    assert "pending explicit coach approval" in policy
    assert "exactly one immutable manual review" in policy
    assert "idempotent reward ledger" in policy
    assert "documentation only" in policy
    assert "executable settlement is in migration 027" in policy
    assert "CREATE OR REPLACE FUNCTION" not in policy
    assert "INSERT INTO public.point_transactions" not in policy


def test_reward_configuration_only_drafts_and_has_no_payout():
    sql = FILES[25]
    assert "c.status<>'draft'" in sql
    assert "c.created_by<>actor.id" in sql
    assert "p_reward_exp NOT IN (25,50,100,150,200)" in sql
    assert "jsonb_set" in sql
    assert "INSERT INTO public.point_transactions" not in sql
    assert "challenge.goal_spec->'reward_exp'" in FILES[17]


def test_goal_and_reward_are_saved_in_one_locked_transaction():
    sql = FILES[26]
    assert "FOR UPDATE" in sql
    assert "c.created_by<>actor.id" in sql
    assert "c.status<>'draft'" in sql
    assert "p_reward_exp NOT IN (25,50,100,150,200)" in sql
    assert "'reward_exp',p_reward_exp" in sql
    assert "INSERT INTO public.point_transactions" not in sql


def test_activation_rejects_incomplete_json_goal_fields():
    sql = FILES[22]
    assert "COALESCE(pg_catalog.char_length" in sql
    assert "false)=false" in sql
    assert "c.goal_spec->>'reward_exp' NOT IN" in sql
    assert "c.goal_spec->>'review_mode' IS DISTINCT FROM 'manual'" in sql


def test_manual_settlement_pays_only_after_reviews_and_locks_challenge():
    sql = FILES[27]
    assert "FOR UPDATE" in sql
    assert "c.created_by<>actor.id" in sql
    assert "All joined participants require a review" in sql
    assert "point_transactions_unique_challenge_reward" in sql
    assert "Orphaned challenge payout exists" in sql
    assert "INSERT INTO public.point_transactions" in sql
    assert "INSERT INTO public.league_coach_challenge_exp_ledger" in sql
    assert "status='settled'" in sql
    assert "Settled challenge payout integrity mismatch" in sql
    assert "RETURN 'settled'" in sql


def test_manual_review_mode_checks_fail_closed_on_missing_json_key():
    for number in (19, 20, 21, 23):
        sql = FILES[number]
        assert "goal_spec->>'review_mode' IS DISTINCT FROM 'manual'" in sql
        assert "goal_spec->>'review_mode'<>'manual'" not in sql


def test_settlement_retry_audits_orphaned_transactions_and_metadata():
    sql = FILES[27]
    assert "Settled challenge metadata integrity mismatch" in sql
    assert "Settled challenge payout integrity mismatch" in sql
    assert "AND NOT EXISTS(SELECT 1 FROM public.league_coach_challenge_exp_ledger l" in sql
    assert "t.category='challenge_exp'" in sql


def test_manual_settlement_rejects_reviews_for_withdrawn_boxers():
    sql = FILES[27]
    assert "Review exists for ineligible participant" in sql
    assert "public.league_coach_challenge_reviews r" in sql
    assert "e.status='joined'" in sql


def test_manual_settlement_requires_joined_participants():
    sql = FILES[27]
    assert "Cannot settle challenge without joined participants" in sql


def test_settlement_migration_preflight_rejects_preexisting_challenge_payouts():
    sql = FILES[27]
    assert "Existing challenge payouts require pre-migration audit" in sql
    assert "WHERE category='challenge_exp'" in sql


def test_boxer_can_rejoin_open_challenge_after_withdrawing():
    sql = FILES[12]
    assert "ON CONFLICT(challenge_id,boxer_id) DO UPDATE" in sql
    assert "SET status='joined'" in sql
    assert "public.league_coach_challenge_entries.status='withdrawn'" in sql
    assert "v_challenge.status<>'open'" in sql


def test_goal_details_is_owner_restricted_and_ui_prefills_saved_draft():
    sql = (MIGRATIONS / "028_coach_challenges_v2_goal_details_review.sql").read_text(encoding="utf-8")
    ui = (MIGRATIONS.parent.parent / "challenges.html").read_text(encoding="utf-8")
    assert "c.created_by<>actor.id" in sql
    assert "c.status<>'draft'" in sql
    assert "REVOKE ALL ON FUNCTION public.coach_challenge_v2_goal_details" in sql
    assert "coach_challenge_v2_goal_details" in ui
    assert "savedGoal.goal_text" in ui
    assert "savedGoal.reward_exp" in ui


def test_goal_details_privacy_smoke_is_wired_to_postgresql_ci():
    workflow = (MIGRATIONS.parent.parent / ".github/workflows/duels-v2-schema-smoke.yml").read_text(encoding="utf-8")
    smoke = (MIGRATIONS.parent / "tests/COACH_CHALLENGES_V2_GOAL_DETAILS_BEHAVIOR_SMOKE.sql").read_text(encoding="utf-8")
    assert "COACH_CHALLENGES_V2_GOAL_DETAILS_BEHAVIOR_SMOKE.sql" in workflow
    assert "Other coach read private draft goal" in smoke
    assert "Boxer read private draft goal" in smoke
    assert "Saved draft goal not returned" in smoke
