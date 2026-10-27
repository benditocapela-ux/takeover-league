-- Rollback für 20261028150000_training_types_duration_notes.sql – behält alle Daten.
--  * Pflichtprüfung (Trigger) wird entfernt: Bemerkung und Dauer sind danach wieder freiwillig.
--  * «Wettkampfsparring» heisst wieder «Sparring», die Bonusregeln werden zurückgeführt.
--  * Neue Trainingsarten: ungenutzte werden gelöscht, bereits genutzte nur deaktiviert (Historie bleibt).
--  * Die Spalten duration_minutes, category und sort_order bleiben bestehen (keine Datenverluste).
BEGIN;
DROP TRIGGER IF EXISTS league_v21_require_training_details ON public.training_submissions;
DROP FUNCTION IF EXISTS league_v21_private.require_training_details();

UPDATE public.training_types SET name='Sparring'
 WHERE name='Wettkampfsparring' AND NOT EXISTS (SELECT 1 FROM public.training_types WHERE name='Sparring');

DO $bonus$
DECLARE fn text; def text; hits integer;
BEGIN
 FOREACH fn IN ARRAY ARRAY['public.recalculate_boxer_bonuses(uuid)','league_private.coach_training_bonus_refresh(uuid)'] LOOP
  IF to_regprocedure(fn) IS NULL THEN CONTINUE; END IF;
  def := pg_get_functiondef(to_regprocedure(fn));
  hits := (SELECT count(*) FROM regexp_matches(def, '''Wettkampfsparring''', 'g'));
  IF hits = 0 THEN CONTINUE; END IF;
  IF hits <> 1 THEN RAISE EXCEPTION 'Unerwartete Definition von %: % Vorkommen', fn, hits; END IF;
  EXECUTE replace(def, '''Wettkampfsparring''', '''Sparring''');
 END LOOP;
END
$bonus$;

DELETE FROM public.training_types t
 WHERE t.name IN ('Wettkampf','Trainingslager / Camp-Tag','Pratzentraining','Sandsack / Rundenarbeit',
   'Schattenboxen / Heimtraining','Seilspringen / Konditionszirkel','Alternative Ausdauer (Rad, Schwimmen, Rudern)',
   'Trainingsassistenz','Mobilität / Regeneration')
   AND NOT EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.training_type_id=t.id)
   AND NOT EXISTS (SELECT 1 FROM public.training_drafts_v2 d WHERE d.training_type_id=t.id);
UPDATE public.training_types SET is_active=false
 WHERE name IN ('Wettkampf','Trainingslager / Camp-Tag','Pratzentraining','Sandsack / Rundenarbeit',
   'Schattenboxen / Heimtraining','Seilspringen / Konditionszirkel','Alternative Ausdauer (Rad, Schwimmen, Rudern)',
   'Trainingsassistenz','Mobilität / Regeneration');
NOTIFY pgrst, 'reload schema';
COMMIT;
