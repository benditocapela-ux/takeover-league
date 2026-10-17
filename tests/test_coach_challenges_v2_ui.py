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
        "coach_challenge_v2_edit_draft",
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


def test_draft_edit_uses_prefilled_form_and_can_be_cancelled():
    html = PAGE.read_text(encoding="utf-8")
    assert "editingId=c.id" in html
    assert "$('title').value=c.title" in html
    assert "$('description').value=c.description||''" in html
    assert "$('kind').value=c.challenge_kind" in html
    assert "$('duration').value=String(c.duration_days)" in html
    assert "$('cancelEdit').addEventListener('click',()=>{if(!formBusy)resetEditor()})" in html
    assert "p_id:editing,...values,p_days:" in html
    assert "p_duration_days:Number($('duration').value)" in html
    assert "prompt(" not in html


def test_cancel_confirmation_does_not_trigger_unnecessary_reload():
    html = PAGE.read_text(encoding="utf-8")
    assert "if(!confirm('Diese Challenge wirklich absagen?'))return false;" in html
    assert "if(changed!==false){try{await refresh()}" in html


def test_challenge_actions_are_serialized():
    html = PAGE.read_text(encoding="utf-8")
    assert "actionBusy=false" in html
    assert "if(actionBusy||formBusy)return;actionBusy=true;" in html
    assert "finally{el.disabled=false;actionBusy=false}" in html


def test_coach_ui_distinguishes_enrollment_from_activation():
    html = PAGE.read_text(encoding="utf-8")
    assert "dadurch starten weder Challenge-Zeitmessung noch EXP-Vergabe" in html
    assert "p_action:'open'" in html
    assert "p_action:'activate'" not in html


def test_form_and_list_actions_share_mutual_exclusion():
    html = PAGE.read_text(encoding="utf-8")
    assert "actionBusy=false,formBusy=false" in html
    assert "if(actionBusy||formBusy)return;actionBusy=true;" in html
    assert "if(formBusy||actionBusy)return;" in html
    assert "formBusy=true;const control=$('createButton')" in html
    assert "$('cancelEdit').disabled=true;" in html
    assert "if(!formBusy)resetEditor()" in html
    assert "formBusy=false}" in html


def test_edit_selection_does_not_trigger_redundant_refresh():
    html = PAGE.read_text(encoding="utf-8")
    assert "$('title').focus();\n    return false;" in html


def test_stale_challenge_fetch_errors_cannot_override_current_state():
    html = PAGE.read_text(encoding="utf-8")
    assert "catch(error){if(current!==sequence)return false;throw error}" in html
    assert "try{if(await refresh())status('Challenge-Übersicht geladen.')}" in html


def test_challenge_filters_are_local_and_preserve_visibility():
    html = PAGE.read_text(encoding="utf-8")
    assert 'id="statusFilter"' in html
    assert 'id="kindFilter"' in html
    assert "allChallenges.filter(c=>" in html
    assert "renderCards(rows,list)" in html
    assert "function renderCards(rows,list){\n for(const c of rows){" in html
    assert "allChallenges=rows||[];renderChallenges();return true;" in html
    assert "$('statusFilter').addEventListener('change',renderChallenges)" in html
    assert "$('kindFilter').addEventListener('change',renderChallenges)" in html


def test_challenge_module_javascript_parses(tmp_path):
    import shutil
    import subprocess

    node = shutil.which("node")
    if not node:
        import pytest
        pytest.skip("Node.js unavailable")
    html = PAGE.read_text(encoding="utf-8")
    script = html.split('<script type="module">', 1)[1].split('</script>', 1)[0]
    module = tmp_path / "challenges.mjs"
    module.write_text(script, encoding="utf-8")
    result = subprocess.run([node, "--check", str(module)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr


def test_successful_writes_are_not_reported_as_failed_on_refresh_error():
    html = PAGE.read_text(encoding="utf-8")
    assert "Aktion gespeichert, aber Aktualisierung fehlgeschlagen:" in html
    assert "Aktion fehlgeschlagen:" in html
    assert "Entwurf gespeichert, aber Aktualisierung fehlgeschlagen:" in html
    assert "saved=true;" in html
    assert "if(!saved)status(" in html
