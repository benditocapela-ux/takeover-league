-- Read-only Dry-Run-Bericht Training 2.0 (ändert nichts): bestätigte Trainings ohne Vereinsstufe in offenen Saisons, die
-- vermutlich Vereinstrainings waren. Vorschlag und Punktedifferenz pro Eintrag. Nicht allein nach Wochentag: es zählen nur Antrag
-- (Training 2.0), Vereinsart (club_only) bzw. die Trainingsart der Pflichteinheit am Pflichttag sowie Ergänzungsarten mit club_only.
-- Nachbuchungen nur einzeln über public.staff_correct_training (Begründung, Audit) und erst nach ausdrücklicher Freigabe.
WITH c AS (
 SELECT s.id, p.display_name AS boxer, s.training_date, to_char(s.training_date,'TMDy') AS tag, t.name AS training_type, tx.points AS aktuell,
  CASE WHEN league_private.suggested_tier(s) IS NOT NULL THEN league_private.suggested_tier(s)
       WHEN (league_private.pflicht_slot_on(s.training_date)).id IS NOT NULL
            AND (t.club_only OR (league_private.pflicht_slot_on(s.training_date)).training_type_id=t.id) THEN 'pflicht'
       WHEN EXISTS (SELECT 1 FROM public.club_extra_trainings e WHERE e.is_active AND e.training_type_id=t.id) AND t.club_only THEN 'ergaenzung' END AS vorschlag,
  s.training_type_id
 FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id JOIN public.profiles p ON p.id=s.boxer_id
 JOIN public.point_transactions tx ON tx.submission_id=s.id
 WHERE s.status='approved' AND s.club_tier IS NULL AND NOT league_private.training_closed_season(s.training_date)
   AND NOT EXISTS (SELECT 1 FROM public.gym_attendance a WHERE a.submission_id=s.id))
SELECT id, boxer, training_date, tag, training_type, aktuell, vorschlag,
 (league_private.training_reward(training_type_id, vorschlag)->>'points')::integer AS neu,
 (league_private.training_reward(training_type_id, vorschlag)->>'points')::integer - aktuell AS differenz
FROM c WHERE vorschlag IS NOT NULL ORDER BY training_date DESC, boxer;
