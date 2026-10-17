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
    assert "status='active'" not in combined


def test_goal_definition_requires_coach_and_keeps_payouts_disabled():
    sql = FILES[17]
    assert "p_review_mode NOT IN ('manual','automatic')" in sql
    assert "challenge.status<>'draft'" in sql
    assert "challenge.created_by<>actor.id" in sql
    assert "p_target_value<=0" in sql
    assert "jsonb_build_object" in sql
