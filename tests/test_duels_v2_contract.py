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
        cls.schema = (ROOT / "supabase/migrations/007_duels_v2_schema_review.sql").read_text(encoding="utf-8")
        cls.invites = (ROOT / "supabase/migrations/008_duels_v2_invitation_rpc_review.sql").read_text(encoding="utf-8")
        cls.settlement = (ROOT / "supabase/migrations/009_duels_v2_settlement_review.sql").read_text(encoding="utf-8")
        cls.reads = (ROOT / "supabase/migrations/010_duels_v2_read_rpc_review.sql").read_text(encoding="utf-8")

    def test_ui_requires_feature_flag(self):
        self.assertIn("feature_key','duels'", self.ui)
        self.assertIn("is_enabled!==true", self.ui)

    def test_coach_must_select_challenger(self):
        self.assertIn('id="challenger"', self.ui)
        self.assertIn("me.role==='boxer'?me.id:$('challenger').value", self.ui)

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

    def test_rematch_releases_expired_active_pair(self):
        self.assertIn("SET status='awaiting_reviews',updated_at=v_now", self.invites)
        self.assertIn("WHERE status='active' AND ends_at<=v_now", self.invites)

    def test_batch_sql_dollar_quotes_balanced(self):
        self.assertEqual(self.settlement.count('AS $'), 2)
        self.assertEqual(self.settlement.count('END $;'), 2)

    def test_read_rpc_authenticated(self):
        self.assertIn("GRANT EXECUTE ON FUNCTION public.duel_v2_list_mine() TO authenticated", self.reads)


if __name__ == "__main__":
    unittest.main()
