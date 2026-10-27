-- Trainer und Admin tragen Trainings für Boxer ein; diese gelten sofort als bestätigt (27.10.2026, Owner-Auftrag).
--  * Neue RPC public.staff_record_training(...): legt das Training an und bestätigt es in derselben Transaktion
--    über die bestehende public.review_training – Punkte, EXP, Bonusregeln, Achievements, Ziele und die
--    Mitteilung «Training bestätigt» entstehen damit exakt wie bei einer normalen Bestätigung.
--  * Pflichtangaben wie beim Boxer (Bemerkung, Trainingsdauer; bei Joggen die Distanz).
--  * Schutz: nur aktive Admins/Trainer; Trainer dürfen sich nicht selbst eintragen (keine Selbstbestätigung);
--    nur aktive, nicht archivierte Boxer; kein Datum in der Zukunft; kein Datum in einer abgeschlossenen Saison
--    (deren Rangliste und Hall of Fame sind eingefroren).
--  * Doppelklick-Schutz über client_request_id (bestehender eindeutiger Index pro Boxer).
--  * Neue Spalte recorded_by: wer das Training eingetragen hat (sichtbar für Boxer und Trainer).
-- Bestehende Trainings, Punkte und EXP bleiben unverändert.
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;

ALTER TABLE public.training_submissions ADD COLUMN IF NOT EXISTS recorded_by uuid REFERENCES public.profiles(id);
GRANT SELECT (recorded_by) ON public.training_submissions TO authenticated;

CREATE OR REPLACE FUNCTION public.staff_record_training(
 p_boxer_id uuid, p_training_type_id bigint, p_training_date date, p_duration_minutes integer,
 p_notes text, p_jogging_km numeric DEFAULT NULL, p_client_request_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; target public.profiles%ROWTYPE; t public.training_types%ROWTYPE;
 existing public.training_submissions%ROWTYPE; new_id uuid; review jsonb; today date;
BEGIN
 SELECT * INTO actor FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role IN ('admin','coach') AND p.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Trainer und Admins dürfen Trainings eintragen' USING ERRCODE='42501'; END IF;

 SELECT * INTO target FROM public.profiles p WHERE p.id=p_boxer_id FOR UPDATE;
 IF NOT FOUND OR target.role NOT IN ('boxer','coach') OR NOT target.is_active OR target.archived_at IS NOT NULL THEN
  RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023';
 END IF;
 IF target.id=actor.id THEN
  RAISE EXCEPTION 'Eigene Trainings bitte normal einreichen – ein anderer Trainer oder der Admin bestätigt sie' USING ERRCODE='42501';
 END IF;

 -- Doppelklick / erneutes Senden: dieselbe Anfrage liefert das bereits eingetragene Training zurück.
 IF p_client_request_id IS NOT NULL THEN
  SELECT * INTO existing FROM public.training_submissions s WHERE s.boxer_id=target.id AND s.client_request_id=p_client_request_id;
  IF FOUND THEN
   RETURN pg_catalog.jsonb_build_object('submission_id',existing.id,'status',existing.status,'duplicate',true);
  END IF;
 END IF;

 SELECT * INTO t FROM public.training_types x WHERE x.id=p_training_type_id AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte eine gültige Trainingsart wählen' USING ERRCODE='22023'; END IF;

 today := (now() AT TIME ZONE 'Europe/Zurich')::date;
 IF p_training_date IS NULL OR p_training_date > today THEN
  RAISE EXCEPTION 'Das Trainingsdatum darf nicht in der Zukunft liegen' USING ERRCODE='22023';
 END IF;
 IF EXISTS (SELECT 1 FROM public.league_seasons_v21 s WHERE s.status='closed' AND p_training_date BETWEEN s.starts_on AND s.ends_on) THEN
  RAISE EXCEPTION 'Dieses Datum gehört zu einer abgeschlossenen Saison und kann nicht mehr eingetragen werden' USING ERRCODE='22023';
 END IF;
 IF t.name='Joggen' AND (p_jogging_km IS NULL OR p_jogging_km <= 0 OR p_jogging_km > 1000) THEN
  RAISE EXCEPTION 'Bitte die Joggingdistanz in km angeben' USING ERRCODE='22023';
 END IF;

 -- Bemerkung und Dauer prüft der bestehende Trigger league_v21_require_training_details.
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,
   jogging_km,client_request_id,recorded_by)
 VALUES (target.id,t.id,p_training_date,coalesce(p_notes,''),'pending',p_duration_minutes,
   CASE WHEN t.name='Joggen' THEN p_jogging_km END,p_client_request_id,actor.id)
 RETURNING id INTO new_id;

 -- Bestätigung über den bestehenden Weg (Punkte, EXP, Boni, Achievements, Ziele, Mitteilung).
 review := public.review_training(new_id,'approved');
 RETURN pg_catalog.jsonb_build_object('submission_id',new_id,'status','approved',
  'points_awarded',coalesce((review->>'points_awarded')::integer,0),'boxer',target.display_name,'training_type',t.name);
END;
$fn$;

REVOKE ALL ON FUNCTION public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
