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
    assert "if(actionBusy||formBusy||refreshBusy)return;actionBusy=true;sequence++;" in html
    assert "finally{el.disabled=false;actionBusy=false}" in html


def test_coach_ui_distinguishes_enrollment_from_activation():
    html = PAGE.read_text(encoding="utf-8")
    assert "dadurch starten weder Challenge-Zeitmessung noch EXP-Vergabe" in html
    assert "p_action:'open'" in html
    assert "p_action:'activate'" not in html


def test_form_and_list_actions_share_mutual_exclusion():
    html = PAGE.read_text(encoding="utf-8")
    assert "actionBusy=false,formBusy=false" in html
    assert "if(actionBusy||formBusy||refreshBusy)return;actionBusy=true;sequence++;" in html
    assert "if(formBusy||actionBusy||refreshBusy)return;" in html
    assert "sequence++;formBusy=true;const control=$('createButton')" in html
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
    assert "allChallenges=rows||[];renderChallenges();" in html
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


def test_filter_count_display():
    html = PAGE.read_text(encoding='utf-8')
    assert 'id="resultCount"' in html
    assert "allChallenges.length" in html


def test_search_is_local_and_warns_when_rpc_result_may_be_truncated():
    html = PAGE.read_text(encoding='utf-8')
    assert 'id="challengeSearch"' in html
    assert "$('challengeSearch').addEventListener('input',renderChallenges)" in html
    assert "toLocaleLowerCase('de-CH').includes(term)" in html
    assert "allChallenges.length===100" in html
    assert 'Höchstens 100 Einträge geladen.' in html


def test_reset_filters_restores_unfiltered_challenge_view():
    html = PAGE.read_text(encoding='utf-8')
    assert 'id="clearFilters"' in html
    assert "$('clearFilters').addEventListener('click'" in html
    assert "$('challengeSearch').value=''" in html
    assert "$('statusFilter').value='all'" in html
    assert "$('kindFilter').value='all'" in html
    assert "renderChallenges();$('challengeSearch').focus()" in html


def test_challenge_cards_show_kind_and_only_actual_dates():
    html = PAGE.read_text(encoding="utf-8")
    assert "const kindLabels={individual:'Individuell'" in html
    assert "kindLabels[c.challenge_kind]||c.challenge_kind" in html
    assert "if(c.starts_at&&c.ends_at)" in html
    assert "timeZone:'Europe/Zurich'" in html
    assert "dateFormatter.format(new Date(c.starts_at))" in html


def test_withdrawal_warns_about_no_rejoin_and_requires_confirmation():
    html = PAGE.read_text(encoding="utf-8")
    assert "Eine erneute Anmeldung ist derzeit nicht möglich." in html
    assert "if(!confirm('Von dieser Challenge abmelden?" in html
    assert "Erneute Anmeldung nach Rückzug derzeit nicht möglich." in html
    assert "Nur Anmeldung: Challenge-Zeitraum und EXP-Vergabe haben noch nicht begonnen." in html


def test_mutations_invalidate_previously_started_list_requests():
    html = PAGE.read_text(encoding="utf-8")
    assert "actionBusy=true;sequence++;$('challengeList').setAttribute('aria-busy','false');el.disabled=true;" in html
    assert "sequence++;$('challengeList').setAttribute('aria-busy','false');formBusy=true;const control=" in html
    assert "if(current!==sequence)return false" in html


def test_manual_refresh_serializes_with_writes_and_other_refreshes():
    html = PAGE.read_text(encoding="utf-8")
    assert "refreshBusy=false" in html
    assert "if(actionBusy||formBusy||refreshBusy)return;actionBusy=true;" in html
    assert "if(formBusy||actionBusy||refreshBusy)return;" in html
    assert "refreshBusy=true;const control=$('refresh');control.disabled=true;" in html
    assert "finally{control.disabled=false;refreshBusy=false}" in html


def test_initialization_failure_is_shown_instead_of_unhandled_rejection():
    html = PAGE.read_text(encoding='utf-8')
    assert "init().catch(e=>{status('Initialisierung fehlgeschlagen:" in html


def test_challenge_refresh_announces_loading_and_clears_stale_busy_state():
    html = PAGE.read_text(encoding="utf-8")
    assert "list.setAttribute('aria-busy','true')" in html
    assert "finally{if(current===sequence)list.setAttribute('aria-busy','false')}" in html
    assert html.count("$('challengeList').setAttribute('aria-busy','false')") >= 2
