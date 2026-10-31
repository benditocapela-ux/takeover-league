#!/usr/bin/env bash
# Parallelität einheitlicher Vereins-Check-in (PR #84). Läuft nach tests/club-today-schema.sql auf derselben Wegwerf-Datenbank.
# 1) 8 gleichzeitige Ein-Klick-Anträge desselben Boxers → genau ein offener Antrag.
# 2) Ein-Klick-Antrag (Transaktion noch offen) und gleichzeitige Gym-Bestätigung mit dem Boxer als anwesend → keine zweite Buchung.
set -euo pipefail
DB="${1:?Datenbank}"; PSQL=(psql -X -h "${PGHOST:-localhost}" -U "${PGUSER:-postgres}" -d "$DB" -v ON_ERROR_STOP=1 -At)
"${PSQL[@]}" -c "INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
 ('00000000-0000-0000-0000-000000000058','20000000-0000-0000-0000-000000000058','Quick 58','boxer',true),
 ('00000000-0000-0000-0000-000000000059','20000000-0000-0000-0000-000000000059','Quick 59','boxer',true) ON CONFLICT DO NOTHING;
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='training_v2';
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key IN ('gym_training','club_checkin_only');" >/dev/null
quick() { "${PSQL[@]}" -c "BEGIN; SELECT set_config('request.jwt.claim.sub','$1',true); SET LOCAL ROLE authenticated;
 SELECT public.submit_scheduled_club_training_today(NULL)->>'status'; $2 COMMIT;" | grep -E '^[a-z_]+$' || true; }
out=$(mktemp); pids=()
for i in $(seq 1 8); do quick 20000000-0000-0000-0000-000000000058 "" >>"$out" & pids+=($!); done
for p in "${pids[@]}"; do wait "$p"; done
N=$("${PSQL[@]}" -c "SELECT count(*) FROM public.training_submissions WHERE boxer_id='00000000-0000-0000-0000-000000000058' AND training_date=league_private.zurich_today()")
S=$(grep -c '^submitted$' "$out" || true); P=$(grep -c '^already_pending$' "$out" || true)
[ "$N" = "1" ] && [ "$S" = "1" ] && [ "$P" = "7" ] || { echo "FAIL Q-par: rows=$N submitted=$S already_pending=$P"; cat "$out"; exit 1; }
echo "PASS Q-par: 8 gleichzeitige Ein-Klick-Anträge → 1 Antrag (1× submitted, 7× already_pending)"
# 2) Gym-Bestätigung wartet auf den Tages-Lock des laufenden Antrags und überspringt den Boxer danach
"${PSQL[@]}" -c "UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='gym_training';" >/dev/null
G=$("${PSQL[@]}" -c "BEGIN; SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-00000000000c',true); SET LOCAL ROLE authenticated;
 SELECT public.staff_open_gym_session((SELECT id FROM public.training_types WHERE name='Techniktraining'),90,'Parallel',NULL)->>'id'; COMMIT;" | grep -E '^[0-9]+$')
# Pflicht-Einheit einer anderen Art: der Ein-Klick-Antrag findet keine passende offene Einheit und reicht einen Antrag ein
"${PSQL[@]}" -c "UPDATE public.gym_sessions SET club_tier='pflicht' WHERE id=$G; UPDATE public.gym_sessions SET status='cancelled' WHERE id<>$G AND status='open' AND session_date=league_private.zurich_today();" >/dev/null
quick 20000000-0000-0000-0000-000000000059 "SELECT pg_sleep(2);" >"$out" & qp=$!
sleep 0.7
"${PSQL[@]}" -c "BEGIN; SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-00000000000c',true); SET LOCAL ROLE authenticated;
 SELECT public.staff_set_gym_attendance($G,'00000000-0000-0000-0000-000000000059',true);
 SELECT public.staff_confirm_gym_session($G); COMMIT;" >/dev/null
wait $qp
R=$(cat "$out")
B=$("${PSQL[@]}" -c "SELECT count(*) FROM public.point_transactions x JOIN public.training_submissions s ON s.id=x.submission_id WHERE s.boxer_id='00000000-0000-0000-0000-000000000059'")
T=$("${PSQL[@]}" -c "SELECT count(*) FROM public.training_submissions WHERE boxer_id='00000000-0000-0000-0000-000000000059'")
"${PSQL[@]}" -c "UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key IN ('gym_training','training_v2');" >/dev/null
[ "$R" = "submitted" ] && [ "$B" = "0" ] && [ "$T" = "1" ] || { echo "FAIL Q-race: quick=$R bookings=$B rows=$T"; exit 1; }
echo "PASS Q-race: Gym-Bestätigung wartet auf den laufenden Ein-Klick-Antrag und bucht nicht doppelt (1 Antrag, 0 Gym-Buchungen)"
