"""Static guard for the reviewed achievement trigger migration.

The behavioral DELETE regression was separately exercised against TEST Supabase
inside a rolled-back transaction. These checks catch accidental removal of the
DELETE trigger branch; they are not a substitute for PostgreSQL integration tests.
"""
from pathlib import Path
import re
import unittest

SQL = (Path(__file__).resolve().parents[1] /
       "supabase/migrations/006_achievement_v2_integrated_review.sql").read_text()


class AchievementTriggerContract(unittest.TestCase):
    def test_trigger_handles_delete(self):
        self.assertRegex(
            SQL,
            r"(?is)CREATE\s+TRIGGER\s+trg_auto_achievements_approved\s+"
            r"AFTER\s+INSERT\s+OR\s+DELETE\s+OR\s+UPDATE\s+OF",
        )

    def test_delete_recalculates_old_owner(self):
        self.assertRegex(
            SQL,
            r"(?is)IF\s+TG_OP\s*=\s*'DELETE'\s+THEN"
            r".*?OLD\.boxer_id\s+FOR\s+UPDATE"
            r".*?recalculate_boxer_achievements_v2\(OLD\.boxer_id\)"
            r".*?RETURN\s+OLD\s*;",
        )

    def test_definer_permissions_remain_restricted(self):
        self.assertRegex(
            SQL,
            r"(?is)REVOKE\s+ALL\s+ON\s+FUNCTION\s+"
            r"public\.recalculate_boxer_achievements_v2\(uuid\)\s+"
            r"FROM\s+PUBLIC\s*,\s*anon\s*,\s*authenticated",
        )
        self.assertRegex(
            SQL,
            r"(?is)REVOKE\s+ALL\s+ON\s+FUNCTION\s+"
            r"public\._award_achievements_on_approval\(\)\s+"
            r"FROM\s+PUBLIC\s*,\s*anon\s*,\s*authenticated",
        )

    def test_ownership_transfer_recalculates_both_boxers(self):
        self.assertRegex(
            SQL,
            r"(?is)OLD\.boxer_id\s+IS\s+DISTINCT\s+FROM\s+NEW\.boxer_id"
            r".*?ORDER\s+BY\s+p\.id\s+FOR\s+UPDATE"
            r".*?recalculate_boxer_achievements_v2\(OLD\.boxer_id\)"
            r".*?recalculate_boxer_achievements_v2\(NEW\.boxer_id\)",
        )

    def test_only_approved_submissions_count(self):
        self.assertRegex(
            SQL, r"(?is)WHERE\s+s\.boxer_id\s*=\s*p_boxer_id"
                 r"\s+AND\s+s\.status\s*=\s*'approved'",
        )

    def test_feature_flag_prevents_disabled_recalculation(self):
        self.assertRegex(
            SQL,
            r"(?is)feature_key\s*=\s*'achievements'"
            r".*?IF\s+v_enabled\s+IS\s+DISTINCT\s+FROM\s+true"
            r"\s+THEN\s+RETURN",
        )

    def test_ledger_is_unique_and_audited(self):
        self.assertRegex(
            SQL,
            r"(?is)ON\s+CONFLICT\s*\(boxer_id\s*,\s*achievement_id\)"
            r"\s+DO\s+NOTHING",
        )
        self.assertIn("INSERT INTO public.achievement_exp_events", SQL)
        self.assertIn("IF v_was IS DISTINCT FROM v_should THEN", SQL)


if __name__ == "__main__":
    unittest.main()
