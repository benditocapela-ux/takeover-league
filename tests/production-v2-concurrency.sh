#!/usr/bin/env bash
# Parallel access tests against disposable PostgreSQL in GitHub Actions only.
set -euo pipefail
test -n "$PGPASSWORD"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
psql_run() { psql -X -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -At "$@"; }

psql_run -f tests/production-v2-concurrency-setup.sql >"$tmpdir/setup.out"

# Both settlement callers must succeed; one pays, the other sees already settled.
settlement="SET ROLE authenticated; SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222'; SELECT public.coach_challenge_v2_settle_manual('90000000-0000-4000-8000-000000000001');"
psql_run -c "$settlement" >"$tmpdir/settle_a.out" 2>"$tmpdir/settle_a.err" & a=$!
psql_run -c "$settlement" >"$tmpdir/settle_b.out" 2>"$tmpdir/settle_b.err" & b=$!
if ! wait "$a"; then cat "$tmpdir/settle_a.err"; exit 1; fi
if ! wait "$b"; then cat "$tmpdir/settle_b.err"; exit 1; fi
psql_run <<'SQL' >"$tmpdir/settle_verify.out"
DO $verify$
BEGIN
 IF (SELECT count(*) FROM public.point_transactions
     WHERE category='challenge_exp' AND boxer_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
     AND exp=100 AND points=0
     AND description LIKE 'Coach Challenge: 90000000-0000-4000-8000-000000000001 | %')<>1
 OR (SELECT count(*) FROM public.league_coach_challenge_exp_ledger
     WHERE challenge_id='90000000-0000-4000-8000-000000000001')<>1
 OR (SELECT status FROM public.league_coach_challenges
     WHERE id='90000000-0000-4000-8000-000000000001')<>'settled'
 THEN RAISE EXCEPTION 'Concurrent settlement duplicated or lost EXP'; END IF;
END $verify$;
SQL

# Two concurrent joins must create one boxer enrollment.
join_sql="SET ROLE authenticated; SET request.jwt.claim.sub='55555555-5555-4555-8555-555555555555'; SELECT public.coach_challenge_v2_join('90000000-0000-4000-8000-000000000002');"
psql_run -c "$join_sql" >"$tmpdir/join_a.out" 2>"$tmpdir/join_a.err" & a=$!
psql_run -c "$join_sql" >"$tmpdir/join_b.out" 2>"$tmpdir/join_b.err" & b=$!
if ! wait "$a"; then cat "$tmpdir/join_a.err"; exit 1; fi
if ! wait "$b"; then cat "$tmpdir/join_b.err"; exit 1; fi
psql_run <<'SQL' >"$tmpdir/join_verify.out"
DO $verify$
BEGIN
 IF (SELECT count(*) FROM public.league_coach_challenge_entries
 WHERE challenge_id='90000000-0000-4000-8000-000000000002'
 AND boxer_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' AND status='joined')<>1
 THEN RAISE EXCEPTION 'Concurrent join duplicated or missed enrollment'; END IF;
END $verify$;
SQL

# Simultaneous duplicate duel invitations: exactly one succeeds.
invite_sql="SET ROLE authenticated; SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111'; SELECT public.duel_v2_invite('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',7);"
psql_run -c "$invite_sql" >"$tmpdir/invite_a.out" 2>"$tmpdir/invite_a.err" & a=$!
psql_run -c "$invite_sql" >"$tmpdir/invite_b.out" 2>"$tmpdir/invite_b.err" & b=$!
successes=0
failures=0
if wait "$a"; then successes=$((successes+1)); else failures=$((failures+1)); fi
if wait "$b"; then successes=$((successes+1)); else failures=$((failures+1)); fi
if [ "$successes" -ne 1 ] || [ "$failures" -ne 1 ]; then
 echo "Expected one invite success and one rejection, got $successes successes"
 cat "$tmpdir/invite_a.out" "$tmpdir/invite_b.out" "$tmpdir/invite_a.err" "$tmpdir/invite_b.err"
 exit 1
fi
psql_run <<'SQL' >"$tmpdir/invite_verify.out"
DO $verify$
BEGIN
 IF (SELECT count(*) FROM public.league_duels WHERE status='pending')<>1 OR
    (SELECT count(*) FROM public.league_duel_events WHERE event_type='invited')<>1
 THEN RAISE EXCEPTION 'Duel invite race created an invalid count'; END IF;
END $verify$;
SQL

# Turn the one accepted invitation into an elapsed duel and reconcile it twice.
duel_id="$(psql_run -c "SELECT id FROM public.league_duels WHERE status='pending' LIMIT 1;")"
test -n "$duel_id"
accept_sql="SET ROLE authenticated; SET request.jwt.claim.sub='55555555-5555-4555-8555-555555555555'; SELECT public.duel_v2_respond('$duel_id',true);"
psql_run -c "$accept_sql" >"$tmpdir/accept.out"
psql_run -c "UPDATE public.league_duels SET accepted_at=now()-INTERVAL '9 days', ends_at=now()-INTERVAL '2 days' WHERE id='$duel_id';" >"$tmpdir/advance.out"
reconcile_sql="SET ROLE authenticated; SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222'; SELECT public.duel_v2_reconcile('$duel_id');"
psql_run -c "$reconcile_sql" >"$tmpdir/reconcile_a.out" 2>"$tmpdir/reconcile_a.err" & a=$!
psql_run -c "$reconcile_sql" >"$tmpdir/reconcile_b.out" 2>"$tmpdir/reconcile_b.err" & b=$!
if ! wait "$a"; then cat "$tmpdir/reconcile_a.err"; exit 1; fi
if ! wait "$b"; then cat "$tmpdir/reconcile_b.err"; exit 1; fi
psql_run <<'SQL' >"$tmpdir/reconcile_verify.out"
DO $verify$
DECLARE id uuid;
BEGIN
 SELECT d.id INTO id FROM public.league_duels d WHERE d.status='settled' LIMIT 1;
 IF id IS NULL OR
  (SELECT count(*) FROM public.league_duel_exp_ledger l
   WHERE l.duel_id=id AND l.awarded_exp=50 AND l.transaction_id IS NOT NULL)<>2 OR
  (SELECT count(*) FROM public.point_transactions t
   WHERE t.category='duel_exp' AND t.description='Duel reward: '||id::text
   AND t.exp=50 AND t.points=0)<>2 OR
  (SELECT count(*) FROM public.league_duel_events e
   WHERE e.duel_id=id AND e.event_type='settled')<>1
 THEN RAISE EXCEPTION 'Concurrent duel reconciliation produced duplicate/missing EXP'; END IF;
END $verify$;
SQL

# Clean temporary fixtures and prove existing scores/users were preserved.
psql_run <<'SQL' >"$tmpdir/cleanup.out"
DELETE FROM public.league_duel_exp_ledger;
DELETE FROM public.point_transactions WHERE category='duel_exp'
 AND description IN (SELECT 'Duel reward: '||id::text FROM public.league_duels);
DELETE FROM public.league_duel_events;
DELETE FROM public.league_duels;
DELETE FROM public.league_coach_challenge_exp_ledger;
DELETE FROM public.league_coach_challenge_reviews;
DELETE FROM public.league_coach_challenge_entries;
DELETE FROM public.league_coach_challenges;
DELETE FROM public.point_transactions
 WHERE category='challenge_exp'
 AND description LIKE 'Coach Challenge: 90000000-0000-4000-8000-000000000001 | %';
UPDATE public.league_feature_flags SET is_enabled=false
 WHERE feature_key IN ('coach_challenges','duels');
DO $verify$
BEGIN
 IF (SELECT count(*) FROM public.point_transactions)<>3
 OR (SELECT count(*) FROM public.profiles)<>5
 OR (SELECT count(*) FROM public.league_duels)<>0
 OR (SELECT count(*) FROM public.league_coach_challenges)<>0
 OR EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key IN ('coach_challenges','duels') AND is_enabled)
 THEN RAISE EXCEPTION 'Concurrent fixture cleanup changed original rows'; END IF;
END $verify$;
SQL
echo "V2 concurrency tests passed: settlement, enrollment, and duel invitation"
