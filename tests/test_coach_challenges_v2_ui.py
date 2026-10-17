"""Static security and workflow contracts for the gated Coach Challenges UI."""
from pathlib import Path

PAGE = Path(__file__).resolve().parents[1] / "challenges.html"


def test_challenges_page_feature_gated():
    html = PAGE.read_text(encoding="utf-8")
    assert "coach_challenges" in html
    assert "flag.data?.is_enabled!==true" in html
    assert "$('app').classList.remove('hidden')" in html
    assert "login.html?next=challenges.html" in html


def test_challenge_actions_only_use_authorized_rpcs():
    html = PAGE.read_text(encoding="utf-8")
    for rpc in (
        "coach_challenge_v2_list",
        "coach_challenge_v2_create_draft",
        "coach_challenge_v2_join",
        "coach_challenge_v2_withdraw",
        "coach_challenge_v2_manage",
    ):
        assert rpc in html
    assert ".from('league_coach_challenges').insert" not in html
    assert ".from('league_coach_challenge_entries').insert" not in html
    assert "textContent=c.title" in html
    assert "textContent=c.description" in html


def test_challenge_status_restrictions_in_ui():
    html = PAGE.read_text(encoding="utf-8")
    assert "me.role==='boxer'&&c.status==='open'" in html
    assert "c.is_creator||me.role==='admin'" in html
    assert "['draft','open'].includes(c.status)" in html
    assert "if(current!==sequence)return false" in html
