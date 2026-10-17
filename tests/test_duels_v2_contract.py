"""Static release guards for Takeover League 2.0 duel integration.

Run: python -m unittest discover -s tests -p 'test_duels_v2_contract.py'
No production credentials, network, or database required.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class DuelContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ui = (ROOT / "duels.html").read_text(encoding="utf-8")
        cls.login = (ROOT / "login.html").read_text(encoding="utf-8")
        cls.preflight = (ROOT / "supabase/tests/DUELS_V2_PREFLIGHT_READ_ONLY.sql").read_text(encoding="utf-8")
        cls.integration_matrix = (ROOT / "supabase/tests/DUELS_V2_INTEGRATION_TEST_MATRIX.md").read_text(encoding="utf-8")
        cls.schema = (ROOT / "supabase/migrations/007_duels_v2_schema_review.sql").read_text(encoding="utf-8")
        cls.invites = (ROOT / "supabase/migrations/008_duels_v2_invitation_rpc_review.sql").read_text(encoding="utf-8")
        cls.settlement = (ROOT / "supabase/migrations/009_duels_v2_settlement_review.sql").read_text(encoding="utf-8")
        cls.reads = (ROOT / "supabase/migrations/010_duels_v2_read_rpc_review.sql").read_text(encoding="utf-8")

    def test_isolated_integration_matrix_covers_payout_safety(self):
        for scenario in ("D09", "D10", "D11", "D14", "D16", "D21", "D23", "D26"):
            with self.subTest(scenario=scenario):
                self.assertIn("| " + scenario + " |", self.integration_matrix)
        self.assertIn("Production remains unchanged", self.integration_matrix)

    def test_login_returns_to_duels(self):
        self.assertIn("next==='duels.html'", self.login)
        self.assertIn("location.replace('./duels.html')", self.login)

    def test_preflight_is_read_only_and_checks_critical_schema(self):
        self.assertIn("BEGIN READ ONLY;", self.preflight)
        self.assertIn("ROLLBACK;", self.preflight)
        self.assertIn("pg_get_constraintdef", self.preflight)
        self.assertIn("('point_transactions','created_by')", self.preflight)
        self.assertIn("('league_feature_flags','is_enabled')", self.preflight)

    def test_ui_requires_feature_flag(self):
        self.assertIn("feature_key','duels'", self.ui)
        self.assertIn("is_enabled!==true", self.ui)

    def test_coach_must_select_challenger(self):
        self.assertIn('id="challenger"', self.ui)
        self.assertIn("me.role==='boxer'?me.id:$('challenger').value", self.ui)

    def test_coach_opponent_selector_excludes_selected_challenger(self):
        self.assertIn("challengerSelect.addEventListener('change',syncOpponentOptions)", self.ui)
        self.assertIn("if(b.id===selectedChallenger)continue", self.ui)

    def test_read_rpcs_are_feature_gated_server_side(self):
        self.assertEqual(self.reads.count("feature_key='duels' AND is_enabled=true"), 2)

    def test_invite_48_hours(self):
        self.assertIn("interval '48 hours'", self.invites)

    def test_accepted_durations(self):
        self.assertIn("p_duration_days NOT IN (7,14)", self.invites)

    def test_opponent_only_accepts(self):
        self.assertIn("v_actor.id<>v_duel.opponent_id", self.invites)

    def test_active_duel_limit(self):
        self.assertIn("v_count>=3", self.invites)

    def test_pair_uniqueness(self):
        self.assertIn("league_duels_one_pending_per_pair", self.schema)
        self.assertIn("league_duels_one_active_per_pair", self.schema)

    def test_awards_have_no_league_points(self):
        self.assertIn("(boxer,0,target_exp,'duel_exp'", self.settlement)

    def test_payout_ledger_unique(self):
        self.assertIn("UNIQUE(duel_id,boxer_id)", self.schema)

    def test_settlement_locks_eligible_submissions_before_scoring(self):
        lock = self.settlement.index("PERFORM 1 FROM public.training_submissions s")
        pending = self.settlement.index("SELECT count(*) INTO pending_count")
        score = self.settlement.index("SELECT COALESCE(sum(t.points)")
        self.assertLess(lock, pending)
        self.assertLess(pending, score)
        self.assertIn("ORDER BY s.id FOR UPDATE", self.settlement)

    def test_pending_training_delays_settlement(self):
        self.assertIn("s.status='pending'", self.settlement)
        self.assertIn("RETURN 'awaiting_reviews'", self.settlement)

    def test_no_direct_table_grants(self):
        for name in ("league_duels", "league_duel_exp_ledger", "league_duel_events"):
            self.assertIn(f"REVOKE ALL ON public.{name}", self.schema)

    def test_settlement_actor_check_is_not_overwritten_by_flag_query(self):
        self.assertIn('actor_found:=FOUND;', self.settlement)
        self.assertIn("IF NOT actor_found OR actor.role NOT IN ('admin','coach')", self.settlement)

    def test_write_rpcs_require_server_side_flag(self):
        self.assertIn("feature_key='duels' AND is_enabled=true", self.invites)
        self.assertIn("feature_key='duels' AND is_enabled=true", self.settlement)

    def test_settlement_locks_profiles_before_duel(self):
        first = self.settlement.index('PERFORM 1 FROM public.profiles')
        second = self.settlement.index('WHERE id=p_duel_id FOR UPDATE')
        self.assertLess(first, second)

    def test_acceptance_rejects_existing_active_pair(self):
        respond = self.invites.split("CREATE OR REPLACE FUNCTION public.duel_v2_respond(", 1)[1]
        self.assertIn("d.id<>p_duel_id", respond)
        self.assertIn("d.status='active' AND d.ends_at>v_now", respond)
        self.assertIn("This boxer pair already has an active duel", respond)
        self.assertIn("league_duels_one_active_per_pair", self.schema)

    def test_respond_locks_profiles_once_before_duel(self):
        respond = self.invites.split("CREATE OR REPLACE FUNCTION public.duel_v2_respond(", 1)[1]
        self.assertEqual(respond.count("ORDER BY id FOR UPDATE"), 1)
        self.assertLess(respond.index("ORDER BY id FOR UPDATE"), respond.index("WHERE id=p_duel_id FOR UPDATE"))
        self.assertIn("Participant profile locks were already acquired", respond)

    def test_reconciliation_refreshes_clock_after_duel_lock(self):
        lock = "SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;"
        refresh = "v_clock:=clock_timestamp();"
        finished = "IF d.ends_at>v_clock THEN RETURN 'in_progress'; END IF;"
        self.assertIn(lock, self.settlement)
        self.assertIn(refresh, self.settlement)
        self.assertLess(self.settlement.index(lock), self.settlement.index(refresh))
        self.assertLess(self.settlement.index(refresh), self.settlement.index(finished))

    def test_invitation_clocks_refresh_after_lock_wait(self):
        invite, respond = self.invites.split("CREATE OR REPLACE FUNCTION public.duel_v2_respond(", 1)
        self.assertIn("v_now:=clock_timestamp();", invite)
        self.assertIn("v_now:=clock_timestamp();", respond)
        self.assertLess(invite.index("ORDER BY id FOR UPDATE"), invite.index("v_now:=clock_timestamp();"))
        self.assertLess(respond.index("WHERE id=p_duel_id FOR UPDATE"), respond.index("v_now:=clock_timestamp();"))
        self.assertLess(respond.index("v_now:=clock_timestamp();"), respond.index("IF v_duel.expires_at<=v_now THEN"))

    def test_duel_invitation_rejects_null_duration(self):
        self.assertIn("IF p_duration_days IS NULL OR p_duration_days NOT IN (7,14) THEN", self.invites)
        self.assertIn("Duel duration must be 7 or 14 days", self.invites)

    def test_duel_response_requires_explicit_boolean(self):
        self.assertIn("IF p_accept IS NULL THEN RAISE EXCEPTION 'Explicit acceptance or decline required'; END IF;", self.invites)
        self.assertIn("IF p_accept=false THEN", self.invites)
        self.assertNotIn("IF p_accept IS DISTINCT FROM true THEN", self.invites)

    def test_rematch_releases_expired_active_pair(self):
        self.assertIn("SET status='awaiting_reviews',updated_at=v_now", self.invites)
        self.assertIn("WHERE status='active' AND ends_at<=v_now", self.invites)

    def test_acceptance_releases_elapsed_pair_before_activation(self):
        marker = "-- An earlier duel can have elapsed while this invitation was pending."
        self.assertIn(marker, self.invites)
        self.assertLess(self.invites.index(marker), self.invites.index("SET status='active',accepted_at=v_now"))

    def test_batch_sql_dollar_quotes_balanced(self):
        self.assertIn("AS $duel_batch$", self.settlement)
        self.assertIn("END $duel_batch$;", self.settlement)
        self.assertEqual(self.settlement.count("$duel_batch$"), 2)
        self.assertIn("AS $$", self.settlement)
        self.assertIn("END $$;", self.settlement)

    def test_category_migration_checks_live_values_before_constraint_replacement(self):
        self.assertIn("DO $duel_category_preflight$", self.settlement)
        self.assertIn("Existing point transaction category would be rejected", self.settlement)
        self.assertIn("Missing point_transactions category CHECK", self.settlement)
        self.assertLess(
            self.settlement.index("DO $duel_category_preflight$"),
            self.settlement.index("DROP CONSTRAINT point_transactions_category_check"),
        )

    def test_database_prevents_duplicate_duel_payouts(self):
        self.assertIn("CREATE UNIQUE INDEX IF NOT EXISTS point_transactions_unique_duel_reward", self.settlement)
        self.assertIn("ON public.point_transactions(boxer_id,description)", self.settlement)
        self.assertIn("WHERE category='duel_exp'", self.settlement)
        self.assertLess(
            self.settlement.index("point_transactions_unique_duel_reward"),
            self.settlement.index("CREATE OR REPLACE FUNCTION public.duel_v2_reconcile("),
        )

    def test_orphaned_reward_transaction_blocks_new_payout(self):
        self.assertIn("Orphaned duel payout transaction", self.settlement)
        self.assertIn("t.description='Duel reward: '||d.id::text", self.settlement)
        self.assertLess(
            self.settlement.index("Orphaned duel payout transaction"),
            self.settlement.index("INSERT INTO public.point_transactions", self.settlement.index("Orphaned duel payout transaction")),
        )

    def test_settled_duel_missing_payout_is_never_recreated(self):
        self.assertIn("IF existing_status='settled' THEN", self.settlement)
        self.assertIn("Settled duel payout transaction missing", self.settlement)
        self.assertLess(
            self.settlement.index("IF existing_status='settled' THEN"),
            self.settlement.index("INSERT INTO public.point_transactions", self.settlement.index("IF existing_status='settled' THEN")),
        )

    def test_duel_payout_ledger_never_accepts_league_points(self):
        self.assertIn("AND t.points=0 AND t.exp=old_exp", self.settlement)
        self.assertIn("VALUES(boxer,0,target_exp,'duel_exp'", self.settlement)
        audit = (ROOT / "supabase/tests/DUELS_V2_LEDGER_AUDIT_READ_ONLY.sql").read_text(encoding="utf-8")
        self.assertIn("t.points IS DISTINCT FROM 0", audit)

    def test_ledger_claim_without_transaction_cannot_issue_second_reward(self):
        self.assertIn("IF old_exp IS DISTINCT FROM 0 THEN", self.settlement)
        self.assertIn("ledger claims EXP without transaction", self.settlement)
        self.assertIn("ELSIF old_exp IS NULL THEN", self.settlement)
        self.assertLess(
            self.settlement.index("IF old_exp IS DISTINCT FROM 0 THEN"),
            self.settlement.index("INSERT INTO public.point_transactions", self.settlement.index("IF old_exp IS DISTINCT FROM 0 THEN")),
        )

    def test_reward_correction_rejects_mismatched_ledger(self):
        self.assertIn("t.id=old_tx AND t.boxer_id=boxer AND t.category='duel_exp'", self.settlement)
        self.assertIn("t.exp=old_exp", self.settlement)
        self.assertIn("Duel reward ledger mismatch", self.settlement)
        self.assertIn("WHERE id=old_tx AND boxer_id=boxer AND category='duel_exp'", self.settlement)
        self.assertIn("IF NOT FOUND THEN", self.settlement)

    def test_paid_duel_is_not_reopened_for_pending_review(self):
        self.assertIn("IF d.status='settled' THEN RETURN 'pending_correction'; END IF;", self.settlement)
        self.assertIn("result.data==='pending_correction'", self.ui)

    def test_coach_can_explicitly_recheck_settled_duels(self):
        self.assertIn("p_include_settled boolean DEFAULT false", self.settlement)
        self.assertIn("(p_include_settled AND d.status='settled')", self.settlement)
        self.assertIn("reconcileBatches(true)", self.ui)
        self.assertIn("p_include_settled:includeSettled", self.ui)
        self.assertIn("id=\"recheckSettled\"", self.ui)

    def test_batch_uses_stable_cursor_instead_of_repeating_first_page(self):
        self.assertIn("p_after uuid DEFAULT NULL", self.settlement)
        self.assertIn("d.id>p_after", self.settlement)
        self.assertIn("ORDER BY d.id LIMIT 100", self.settlement)
        self.assertIn("p_after:cursor", self.ui)
        self.assertIn("batchCursors[mode]=cursor", self.ui)

    def test_read_rpc_authenticated(self):
        self.assertIn("GRANT EXECUTE ON FUNCTION public.duel_v2_list_mine() TO authenticated", self.reads)

    def test_expired_invitations_have_no_acceptance_controls(self):
        self.assertIn("d.opponent_id===me.id&&new Date(d.expires_at)>new Date()", self.ui)
        self.assertIn("Einladung abgelaufen – keine Annahme mehr möglich.", self.ui)
        self.assertIn("response.data==='expired'", self.ui)

    def test_invitation_response_prevents_double_clicks(self):
        self.assertIn("for(const control of actions.querySelectorAll('button'))control.disabled=true", self.ui)
        self.assertIn("finally{for(const control of actions.querySelectorAll('button'))control.disabled=false;}", self.ui)


if __name__ == "__main__":
    unittest.main()
