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
    assert "INSERT INTO public.point_transactions" not in combined
    assert "UPDATE public.point_transactions" not in combined
    assert "INSERT INTO public.league_coach_challenge_exp_ledger" not in combined
    assert "INSERT INTO public.point_transactions" not in combined


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
    assert "Automatic goal settlement is not implemented" in sql
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
