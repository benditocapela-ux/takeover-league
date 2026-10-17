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
]


class DuelSqlSyntaxTests(unittest.TestCase):
    def test_sql_files_parse_without_postgres_connection(self):
        for relative in SQL_FILES:
            with self.subTest(file=relative):
                statements = parse_sql((ROOT / relative).read_text(encoding="utf-8"))
                self.assertGreater(len(statements), 0)


if __name__ == "__main__":
    unittest.main()
