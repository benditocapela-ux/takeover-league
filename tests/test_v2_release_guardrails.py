"""Release guardrails for disabled V2 features and unapproved payouts.

These checks intentionally fail if a future change bypasses owner approval.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
CHALLENGE = sorted(MIGRATIONS.glob("01[1-9]_coach_challenges_v2_*.sql"))
DUEL = sorted(MIGRATIONS.glob("00[7-9]_duels_v2_*.sql"))
PAGES = (ROOT / "challenges.html", ROOT / "duels.html")


def _sql_code(path):
    source = path.read_text(encoding="utf-8")
    return re.sub(r"--[^\n]*", "", source).lower()


def test_all_v2_sql_changes_remain_review_only():
    assert len(CHALLENGE) >= 6 and len(DUEL) >= 3
    for path in CHALLENGE + DUEL:
        assert any(label in path.read_text(encoding="utf-8").upper() for label in ("REVIEW ONLY", "DRAFT ONLY")), path


def test_v2_feature_flags_are_not_enabled_in_migrations():
    for path in CHALLENGE + DUEL:
        sql = _sql_code(path)
        assert not re.search(r"\bupdate\s+public\.league_feature_flags\s+set\s+is_enabled\s*=\s*true\b", sql), path
        assert not re.search(r"values\s*\(\s*'(?:duels|coach_challenges)'\s*,\s*true\s*\)", sql), path


def test_challenge_rewards_and_activation_remain_blocked():
    for path in CHALLENGE:
        sql = _sql_code(path)
        assert not re.search(r"\binsert\s+into\s+public\.point_transactions\b", sql), path
        assert not re.search(r"\bupdate\s+public\.point_transactions\b", sql), path
        assert not re.search(r"\binsert\s+into\s+public\.league_coach_challenge_exp_ledger\b", sql), path
        assert not re.search(r"\bstatus\s*=\s*'active'", sql), path


def test_v2_pages_require_feature_flag():
    for page, flag in zip(PAGES, ("coach_challenges", "duels")):
        html = page.read_text(encoding="utf-8")
        assert flag in html, page
        assert "is_enabled" in html, page
        assert "getUser()" in html, page
