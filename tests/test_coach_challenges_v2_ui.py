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
        "coach_challenge_v2_save_goal_reward",
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
    assert "Danach die Anmeldung öffnen und die Challenge starten." in html
    assert "Automatische Abrechnung bleibt deaktiviert." in html
    assert "p_action:'open'" in html
    assert "p_action:'activate'" not in html


def test_form_and_list_actions_share_mutual_exclusion():
    html = PAGE.read_text(encoding="utf-8")
    assert "actionBusy=false,formBusy=false" in html
    assert "if(actionBusy||formBusy||refreshBusy)return;actionBusy=true;sequence++;" in html
    assert "if(formBusy||actionBusy||refreshBusy)return;" in html
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


def test_withdrawal_allows_rejoin_only_while_open_and_requires_confirmation():
    html = PAGE.read_text(encoding="utf-8")
    assert "Solange die Anmeldung offen ist, kannst du erneut teilnehmen." in html
    assert "if(!confirm('Von dieser Challenge abmelden?" in html
    assert "c.status==='open'&&(!c.my_enrollment_status||c.my_enrollment_status==='withdrawn')" in html
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


def test_goal_editor_supports_manual_and_automatic_goals_without_payout():
    html = PAGE.read_text(encoding="utf-8")
    assert 'id="goalPanel"' in html
    assert 'id="goalForm"' in html
    assert 'value="manual"' in html
    assert 'value="automatic"' in html
    assert "if(c.status==='draft')actions.append(button('Ziel festlegen'" in html
    assert "p_challenge_id:goalEditingId" in html
    assert "p_review_mode:$('goalMode').value" in html
    assert "p_target_value:target,p_metric:automatic?" in html
    assert "if(formBusy||actionBusy||refreshBusy||!goalEditingId)return;" in html
    assert "if(!Number.isFinite(target)" not in html
    assert "Number.isFinite(target)" in html
    assert "Noch keine EXP-Vergabe." in html


def test_automatic_goal_requires_explicit_supported_training_metric():
    html = PAGE.read_text(encoding="utf-8")
    assert 'id="goalMetric"' in html
    assert 'value="jogging_km"' in html
    assert 'value="technique_minutes"' in html
    assert "p_metric:automatic?$('goalMetric').value:null" in html


def test_goal_progress_preview_is_read_only_and_validated():
    source = (PAGE.parent / "coach-challenge-progress.js").read_text(encoding="utf-8")
    assert "entry.status !== 'approved'" in source
    assert "entry.training_date < startDate" in source
    assert "entry.training_date > endDate" in source
    assert "Number.isFinite(achieved)" in source
    assert "Array.isArray(submissions)" in source
    assert "target > 1000000" in source
    assert "point_transactions" not in source
    assert "awarded_exp" not in source.lower()
    assert "insert into" not in source.lower()


def test_manual_review_form_calls_authorized_rpc_without_local_exp_payout():
    html = PAGE.read_text(encoding="utf-8")
    assert 'id="reviewPanel"' in html
    assert 'id="reviewReason"' in html
    assert "coach_challenge_v2_review_manual" in html
    assert "p_approved:" in html and "p_reason:" in html
    assert "reviewChallengeId=null" in html
    assert "point_transactions" not in html


def test_trainer_activation_and_review_transition_have_confirmation():
    html = PAGE.read_text(encoding="utf-8")
    assert "coach_challenge_v2_activate" in html
    assert "coach_challenge_v2_begin_reviews" in html
    assert "Challenge jetzt starten?" in html
    assert "Die Datenbank prüft den Ablauf nochmals." in html
    assert "Es wurden keine EXP ausgezahlt." in html


def test_review_picker_only_shows_unreviewed_participants():
    html = PAGE.read_text(encoding="utf-8")
    assert 'id="reviewBoxer"' in html
    assert "coach_challenge_v2_review_candidates" in html
    assert "coach_challenge_v2_review_status" in html
    assert "new Set((reviews||[]).map(r=>r.boxer_id))" in html
    assert "select.disabled=!eligible.length" in html


def test_goal_editor_can_save_trainer_chosen_exp_reward():
    html = PAGE.read_text(encoding="utf-8")
    assert 'id="goalReward"' in html
    for reward in (25, 50, 100, 150, 200):
        assert f'<option value="{reward}">{reward} EXP</option>' in html
    assert "coach_challenge_v2_save_goal_reward" in html
    assert "p_reward_exp:Number($('goalReward').value)" in html
    assert "await rpc('coach_challenge_v2_set_reward'" not in html


def test_coach_settlement_requires_confirmation_and_rpc():
    html = PAGE.read_text(encoding="utf-8")
    assert "if(c.status==='awaiting_reviews')actions.append(button('Challenge abrechnen'" in html
    assert "Alle Teilnehmer bewertet? Die EXP werden jetzt einmalig vergeben." in html
    assert "coach_challenge_v2_settle_manual" in html
    assert "p_challenge_id:c.id" in html


def test_begin_reviews_button_hidden_until_challenge_expiry():
    html = PAGE.read_text(encoding="utf-8")
    assert "c.status==='active'&&c.ends_at&&new Date(c.ends_at).getTime()<=Date.now()" in html


def test_automatic_review_option_is_disabled_until_backend_supports_it():
    html = PAGE.read_text(encoding="utf-8")
    assert '<option value="automatic" disabled>' in html


def test_goal_editor_only_switches_after_private_draft_read_succeeds():
    from pathlib import Path
    html = (Path(__file__).resolve().parents[1] / "challenges.html").read_text(encoding="utf-8")
    read = "const savedGoal=await rpc('coach_challenge_v2_goal_details'"
    select = "goalEditingId=c.id;$('goalChallengeName').textContent=c.title;"
    assert html.index(read) < html.index(select)


def test_isolated_preview_never_uses_production_auth_or_redirect():
    root = PAGE.parent
    challenge = (root / "challenges-test.html").read_text(encoding="utf-8")
    login = (root / "login-test.html").read_text(encoding="utf-8")
    test_url = "https://cfgdvcccsqwfjajuizsr.supabase.co"
    prod_url = "https://iqarjivcrddcixrvqbfb.supabase.co"
    for html in (challenge, login):
        assert test_url in html
        assert prod_url not in html
        assert "TEST ONLY" in html
    assert "location.replace('./login-test.html')" in challenge
    assert "location.replace('./challenges-test.html')" in login
    assert "signInWithPassword" in login
    assert "signUp(" not in login
    assert "sb_secret_" not in login + challenge

    assert 'data-environment="test"' in challenge
    assert 'TEST ONLY</span>' in challenge
    assert '<a href="./index.html">' not in challenge
    assert '<a href="./duels.html">' not in challenge
    assert "db.auth.signOut()" in challenge
    assert "location.replace('./login-test.html')" in challenge


def test_test_preview_matches_production_challenge_logic():
    """Keep the test-only page from silently drifting away from the real UI."""
    import re
    root = PAGE.parent
    production = PAGE.read_text(encoding="utf-8")
    preview = (root / "challenges-test.html").read_text(encoding="utf-8")
    rpc_pattern = r"rpc\('([^']+)'"
    assert set(re.findall(rpc_pattern, preview)) == set(re.findall(rpc_pattern, production))
    assert "c.my_enrollment_status==='withdrawn'" in preview
    assert "coach_challenge_v2_settle_manual" in preview
    assert "coach_challenge_v2_review_manual" in preview
    assert "flag.data?.is_enabled!==true" in preview


def test_isolated_test_auth_requires_secure_origin():
    root = PAGE.parent
    for filename in ("login-test.html", "challenges-test.html"):
        html = (root / filename).read_text(encoding="utf-8")
        assert "location.protocol!=='https:'" in html
        assert "location.hostname!=='localhost'" in html
        assert "location.hostname!=='127.0.0.1'" in html
        assert "throw Error('Insecure test" in html
