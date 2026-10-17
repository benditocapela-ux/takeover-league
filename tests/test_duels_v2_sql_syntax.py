"""Parse draft duel SQL with PostgreSQL's grammar; never connect to a database."""
from pathlib import Path
import unittest

from pglast import parse_sql

ROOT = Path(__file__).resolve().parents[1]
SQL_FILES = [
    "supabase/migrations/007_duels_v2_schema_review.sql",
    "supabase/migrations/008_duels_v2_invitation_rpc_review.sql",
    "supabase/migrations/009_duels_v2_settlement_review.sql",
    "supabase/migrations/010_duels_v2_read_rpc_review.sql",
    "supabase/tests/DUELS_V2_PREFLIGHT_READ_ONLY.sql",
    "supabase/tests/DUELS_V2_LEDGER_AUDIT_READ_ONLY.sql",
    *[f"supabase/migrations/{i:03d}_{name}.sql" for i,name in [
        (11,"coach_challenges_v2_schema_review"),
        (12,"coach_challenges_v2_enrollment_rpc_review"),
        (13,"coach_challenges_v2_management_rpc_review"),
        (14,"coach_challenges_v2_withdraw_rpc_review"),
        (15,"coach_challenges_v2_read_rpc_review"),
        (16,"coach_challenges_v2_edit_draft_rpc_review"),
    ]],
    *[f"supabase/tests/COACH_CHALLENGES_V2_{name}.sql" for name in [
        "SCHEMA_BEHAVIOR_SMOKE","ENROLLMENT_BEHAVIOR_SMOKE",
        "MANAGEMENT_BEHAVIOR_SMOKE","WITHDRAW_BEHAVIOR_SMOKE",
        "READ_BEHAVIOR_SMOKE","EDIT_DRAFT_BEHAVIOR_SMOKE",
        "AUDIT_READ_ONLY","INTEGRITY_ASSERTIONS_SMOKE","API_PERMISSIONS_SMOKE",
    ]],
]


class DuelSqlSyntaxTests(unittest.TestCase):
    def test_sql_files_parse_without_postgres_connection(self):
        for relative in SQL_FILES:
            with self.subTest(file=relative):
                statements = parse_sql((ROOT / relative).read_text(encoding="utf-8"))
                self.assertGreater(len(statements), 0)


if __name__ == "__main__":
    unittest.main()
