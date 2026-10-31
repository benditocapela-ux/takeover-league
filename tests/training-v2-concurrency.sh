#!/usr/bin/env bash
# Gleichzeitige Bestätigungen (Training 2.0): zwei Trainer bestätigen dasselbe Training parallel und tippen mehrfach.
# Läuft nach tests/training-v2-schema.sql auf derselben Wegwerf-Datenbank. Erwartung: genau eine Punktebuchung.
set -euo pipefail
DB="${1:?Datenbank}"; PSQL=(psql -X -h "${PGHOST:-localhost}" -U "${PGUSER:-postgres}" -d "$DB" -v ON_ERROR_STOP=1 -At)
SUB=$("${PSQL[@]}" -c "UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='training_v2';
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes)
 SELECT '00000000-0000-0000-0000-000000000003', id, DATE '2026-08-01'+(SELECT count(*)::integer FROM public.training_submissions WHERE notes='Parallel'), 'Parallel', 'pending', 90 FROM public.training_types WHERE name='Reguläres Boxtraining'
 RETURNING id;" | grep -E "^[0-9a-f-]{36}$")
call() { "${PSQL[@]}" -c "BEGIN; SELECT set_config('request.jwt.claim.sub','$1',true); SET LOCAL ROLE authenticated;
 SELECT public.staff_review_training('$SUB','approved')->>'already'; COMMIT;" >/dev/null; }
pids=()
for i in 1 2 3; do call 10000000-0000-0000-0000-00000000000c & pids+=($!); call 10000000-0000-0000-0000-00000000000a & pids+=($!); done
for p in "${pids[@]}"; do wait "$p"; done
N=$("${PSQL[@]}" -c "SELECT count(*) FROM public.point_transactions WHERE submission_id='$SUB'")
S=$("${PSQL[@]}" -c "SELECT status FROM public.training_submissions WHERE id='$SUB'")
"${PSQL[@]}" -c "UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='training_v2';" >/dev/null
[ "$N" = "1" ] && [ "$S" = "approved" ] || { echo "FAIL: $N Buchungen, Status $S"; exit 1; }
echo "PASS 18: 6 gleichzeitige Bestätigungen durch zwei Trainer → genau 1 Buchung"
