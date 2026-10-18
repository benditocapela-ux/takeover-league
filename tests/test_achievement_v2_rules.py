"""Achievement V2 pure-rule regression tests; no database or network access.
Run: python -m unittest discover -s tests -p 'test_achievement_v2_rules.py' -v
These verify business thresholds only, NOT SQL security, triggers, or concurrency.
"""
import unittest

THRESHOLDS = {
    "sessions": (10, 25, 50, 100),
    "days": (10, 25, 60, 120),
    "jogging_km": (25, 75, 150, 300),
    "sprints": (5, 15, 30, 60),
    "technique_minutes": (300, 900, 1800, 3600),
    "sparring": (5, 15, 30, 60),
    "strength": (10, 25, 50, 100),
    "complete": (1, 3, 7, 15),
}
REWARDS = (25, 60, 125, 250)


def eligible(metrics):
    return {
        (name, tier): reward
        for name, thresholds in THRESHOLDS.items()
        for tier, (threshold, reward) in enumerate(zip(thresholds, REWARDS), 1)
        if metrics.get(name, 0) >= threshold
    }


def reconcile(current_awards, metrics):
    target = eligible(metrics)
    added = set(target) - set(current_awards)
    revoked = set(current_awards) - set(target)
    delta = sum(target[k] for k in added) - sum(current_awards[k] for k in revoked)
    return target, delta


class AchievementRulesTest(unittest.TestCase):
    def test_32_rules(self):
        self.assertEqual(sum(map(len, THRESHOLDS.values())), 32)

    def test_royce_preview(self):
        # 10+ approved sessions, all other thresholds below minimum.
        current, delta = reconcile({}, {"sessions": 10, "days": 9})
        self.assertEqual(current, {("sessions", 1): 25})
        self.assertEqual(delta, 25)

    def test_idempotent(self):
        first, first_delta = reconcile({}, {"sessions": 10})
        second, second_delta = reconcile(first, {"sessions": 10})
        self.assertEqual((first_delta, second_delta), (25, 0))
        self.assertEqual(first, second)

    def test_skipped_thresholds(self):
        awards = eligible({"sessions": 25})
        self.assertEqual(sum(awards.values()), 85)

    def test_revocation_and_reearning(self):
        initial, _ = reconcile({}, {"sessions": 10})
        revoked, delta = reconcile(initial, {"sessions": 9})
        self.assertEqual((revoked, delta), ({}, -25))
        restored, delta = reconcile(revoked, {"sessions": 10})
        self.assertEqual((restored, delta), (initial, 25))

    def test_technique_boundary(self):
        self.assertEqual(eligible({"technique_minutes": 299}), {})
        self.assertEqual(eligible({"technique_minutes": 300}), {("technique_minutes", 1): 25})

    def test_complete_requires_each_type(self):
        # 'complete' must be derived from MIN(count per each of six types).
        counts = (10, 10, 10, 10, 10, 0)
        self.assertNotIn(("complete", 1), eligible({"complete": min(counts)}))
        counts = (10, 10, 10, 10, 10, 1)
        self.assertIn(("complete", 1), eligible({"complete": min(counts)}))

    def test_all_maximum(self):
        metrics = {k: v[-1] for k, v in THRESHOLDS.items()}
        awards = eligible(metrics)
        self.assertEqual(len(awards), 32)
        self.assertEqual(sum(awards.values()), 8 * sum(REWARDS))


if __name__ == "__main__":
    unittest.main()
