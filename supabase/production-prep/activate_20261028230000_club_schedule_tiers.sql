-- AKTIVIERUNG Etappe 6a (nur nach ausdrücklicher Freigabe des Owners). Einmalig ausführen.
-- 1. Punktwerte der Trainingsarten: Vereinsarten (Reguläres Boxtraining, Techniktraining, Pratzentraining, Sandsack) und
--    Sprint-Intervalle = 30; «Technisches Sparring» wird aktiv.
-- 2. Bestehende bestätigte Trainings werden nach Stundenplan eingestuft und neu bewertet (Owner-Entscheid 28.10.2026):
--    Vereinsart Mo/Mi/Sa → Pflicht 60 · Vereinsart Di/Do → Ergänzung 40 · Krafttraining Do → Ergänzung 40 ·
--    Vereinsart Fr/So → Heimtraining 30 · Sprint-Intervalle 30 · alles andere unverändert. Abgeschlossene Saisons bleiben unverändert.
--    Jede Änderung steht in public.training_audit (Beschreibung «Training (umgewertet nach Stundenplan)») und ist mit
--    deactivate_20261028230000_club_schedule_tiers.sql vollständig rücknehmbar.
-- 3. Flags gym_training und weekly_quests einschalten.
BEGIN;
SELECT league_private.activate_club_tiers((SELECT id FROM public.profiles WHERE role='admin' AND is_active AND archived_at IS NULL ORDER BY id LIMIT 1)) AS ergebnis;
UPDATE public.league_feature_flags SET is_enabled=true, updated_at=now() WHERE feature_key IN ('gym_training','weekly_quests');
COMMIT;
