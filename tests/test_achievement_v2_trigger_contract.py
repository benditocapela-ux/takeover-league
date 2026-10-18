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


if __name__ == "__main__":
    unittest.main()
