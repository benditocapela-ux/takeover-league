"""Run: python3 supabase/tests/CHALLENGE_V2_MANUAL_SETTLEMENT_STATIC_AUDIT.py"""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'migrations'
files = {n: next(root.glob(f'{n}_*.sql')).read_text() for n in ('025', '026', '027', '028')}
required = {
 '025': ['p_reward_exp NOT IN (25,50,100,150,200)', "c.status<>'draft'", 'FOR UPDATE', 'SECURITY DEFINER', 'REVOKE ALL', 'GRANT EXECUTE'],
 '026': ['SECURITY DEFINER', 'FOR UPDATE', 'REVOKE ALL', 'GRANT EXECUTE'],
 '027': ["category='challenge_exp'", 'FOR UPDATE', 'IF reward>0 THEN', 'ELSE 0 END', 'Existing challenge ledger prevents first settlement', 'All joined participants require a review', 'REVOKE ALL', 'GRANT EXECUTE', "c.status='settled'"],
 '028': ['SECURITY DEFINER', 'REVOKE ALL', 'GRANT EXECUTE'],
}
for number, tokens in required.items():
    missing = [token for token in tokens if token not in files[number]]
    if missing:
        raise SystemExit(f'{number}: missing safeguards: {missing}')
    print(f'{number}: {len(tokens)} safeguards present')
print('Static audit passed. This is NOT a runtime authorization or payout test.')
